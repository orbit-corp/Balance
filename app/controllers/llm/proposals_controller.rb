class Llm::ProposalsController < ApplicationController
  before_action :set_llm_chat
  before_action :set_proposal

  def update
    return respond_with_card if @proposal.account_creation_proposal?
    return respond_with_card unless @proposal.pending?

    return respond_with_card(draft.errors) if draft.invalid?

    @proposal.update!(data: draft.data)
    respond_with_card
  end

  def confirm
    errors = if @proposal.account_creation_proposal?
      @proposal.confirm_accounts!(draft: account_draft)
    else
      @proposal.confirm!(draft: journal_entry_draft)
    end

    resume_after_account_creation if errors.nil? && @proposal.reload.account_creation_proposal? && @proposal.confirmed?
    respond_with_card(errors)
  rescue ActiveRecord::RecordInvalid => e
    respond_with_card([ e.message ])
  end

  def dismiss
    @proposal.dismiss! if @proposal.pending?
    respond_with_card
  end

  private

  def set_llm_chat
    @llm_chat = current_workspace.llm_chats.find_by!(uuid: params[:chat_uuid])
  end

  def set_proposal
    @proposal = @llm_chat.proposals.find(params[:id])
  end

  def proposal_params
    params.expect(proposal: [ :description, :entry_date, :reverses_journal_entry_id, lines: [ [ :account_id, :side, :amount_naira, :counterparty_name ] ] ])
  end

  def journal_entry_draft
    @journal_entry_draft ||= Llm::JournalEntryProposal.from_form(workspace: current_workspace, params: proposal_params)
  end

  alias_method :draft, :journal_entry_draft

  def account_draft
    @account_draft ||= Llm::AccountCreationProposal.new(workspace: current_workspace, data: @proposal.data)
  end

  def resume_after_account_creation
    created = @proposal.data.fetch("created_accounts").map { |account| "#{account.fetch("name")} (id #{account.fetch("id")})" }.join(", ")
    session = @proposal.llm_message&.response_turn&.llm_transaction_session
    message = @llm_chat.resume_turn(
      "ACCOUNT PROPOSAL APPROVED: Created #{created}. Continue the user's pending transaction now. " \
      "Call list_accounts to refresh IDs, then call propose_entry. Do not ask for account approval again.",
      transaction_session: session
    )
    @resumed_turn = message.llm_turn
  end

  def respond_with_card(errors = nil)
    partial = Llm::MessagesHelper::PROPOSAL_PARTIALS.fetch(@proposal.proposal_type)

    respond_to do |format|
      format.turbo_stream do
        streams = [ turbo_stream.replace(
          "proposal_#{@proposal.id}", partial: partial,
          locals: { proposal: @proposal, errors: errors }
        ) ]
        if @resumed_turn
          streams << turbo_stream.append(
            "llm_messages", partial: "llm/messages/turn_status",
            locals: { turn: @resumed_turn }
          )
        end
        render turbo_stream: streams
      end
      format.html { redirect_to chat_path(@llm_chat) }
    end
  end
end

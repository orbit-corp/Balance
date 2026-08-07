class Llm::ProposalsController < ApplicationController
  before_action :set_llm_chat
  before_action :set_proposal

  def update
    return respond_with_card unless @proposal.pending?

    return respond_with_card(draft.errors) if draft.invalid?

    @proposal.update!(data: draft.data)
    respond_with_card
  end

  def confirm
    return respond_with_card unless @proposal.pending?

    return respond_with_card(draft.errors) if draft.invalid?

    ActiveRecord::Base.transaction do
      journal_entry = draft.build_journal_entry!
      @proposal.confirm!(journal_entry: journal_entry)
    end

    respond_with_card
  rescue ActiveRecord::RecordInvalid => e
    respond_with_card([ e.message ])
  end

  def dismiss
    @proposal.dismiss! if @proposal.pending?
    respond_with_card
  end

  private

  def set_llm_chat
    @llm_chat = current_workspace.llm_chats.find(params[:chat_id])
  end

  def set_proposal
    @proposal = @llm_chat.proposals.find(params[:id])
  end

  def proposal_params
    params.require(:proposal).permit(:description, :entry_date, lines: [ :account_id, :side, :amount_naira, :counterparty_name ])
  end

  def draft
    @draft ||= Llm::JournalEntryProposal.from_form(workspace: current_workspace, params: proposal_params)
  end

  def respond_with_card(errors = nil)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "proposal_#{@proposal.id}",
          partial: "llm/messages/proposals/journal_entry",
          locals: { proposal: @proposal, errors: errors }
        )
      end
      format.html { redirect_to chat_path(@llm_chat) }
    end
  end
end

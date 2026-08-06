class Llm::ProposalsController < ApplicationController
  before_action :set_llm_chat
  before_action :set_proposal

  def update
    return respond_with_card unless @proposal.pending?

    @proposal.update!(data: @proposal.data.merge(edited_data))
    respond_with_card
  end

  def confirm
    return respond_with_card unless @proposal.pending?

    errors = confirmation_errors
    if errors.any?
      return respond_with_card(errors)
    end

    ActiveRecord::Base.transaction do
      journal_entry = build_journal_entry!
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

  def edited_data
    lines = (proposal_params[:lines] || {}).values.map do |line|
      {
        "account_id" => line[:account_id].presence&.to_i,
        "side" => line[:side],
        "amount_kobo" => (line[:amount_naira].presence.to_f * 100).round,
        "counterparty_name" => line[:counterparty_name].presence
      }
    end

    {
      "description" => proposal_params[:description],
      "entry_date" => proposal_params[:entry_date],
      "lines" => lines,
      "needs_attention" => lines.any? { |line| line["account_id"].blank? } ? @proposal.needs_attention : nil
    }
  end

  # data is JSONB and unvalidated at the database level — this is the one place that
  # re-checks everything from scratch before a JournalEntry is ever built.
  def confirmation_errors
    errors = []
    errors << "date is required" if @proposal.entry_date.blank? || !valid_date?(@proposal.entry_date)
    errors << "an entry needs at least two lines" if @proposal.lines.size < 2

    @proposal.lines.each do |line|
      if line["account_id"].blank?
        errors << "every line needs an account"
      elsif !current_workspace.accounts.exists?(id: line["account_id"])
        errors << "an account on this entry does not belong to this workspace"
      end
    end

    errors << "debits and credits must balance" if errors.empty? && @proposal.total_debit_kobo != @proposal.total_credit_kobo

    errors
  end

  def valid_date?(value)
    Date.parse(value.to_s)
    true
  rescue ArgumentError, TypeError
    false
  end

  def build_journal_entry!
    entry = current_workspace.journal_entries.build(
      description: @proposal.description,
      entry_date: Date.parse(@proposal.entry_date)
    )

    @proposal.lines.each do |line|
      account = current_workspace.accounts.find(line["account_id"])
      journal_entry_line = entry.journal_entry_lines.build(account: account)
      naira = line["amount_kobo"].to_i / 100.0
      line["side"] == "debit" ? (journal_entry_line.debit = naira) : (journal_entry_line.credit = naira)
    end

    entry.save!
    entry
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

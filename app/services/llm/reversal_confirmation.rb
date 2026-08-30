class Llm::ReversalConfirmation
  attr_reader :errors, :proposal, :superseded

  def self.entry_data(entry, use_original_date: false)
    {
      "source_entry_id" => entry.id,
      "description" => entry.description,
      "entry_date" => entry.entry_date.iso8601,
      "use_original_date" => use_original_date,
      "lines" => entry.journal_entry_lines.map do |line|
        {
          "account_id" => line.account_id,
          "account_name" => line.account.name,
          "side" => line.debit_kobo.positive? ? "debit" : "credit",
          "amount_kobo" => line.debit_kobo.positive? ? line.debit_kobo : line.credit_kobo
        }
      end
    }
  end

  def initialize(confirmation)
    @confirmation = confirmation
    @chat = confirmation.llm_chat
    @errors = []
    @superseded = []
  end

  def confirm
    @chat.with_lock do
      @confirmation.lock!
      return self unless @confirmation.reversal_confirmation?
      if @confirmation.confirmed?
        @proposal = @chat.proposals.find(@confirmation.data.fetch("reversal_proposal_id"))
        return self
      end
      return self unless @confirmation.pending?

      entry = @chat.workspace.journal_entries.includes(journal_entry_lines: :counterparty)
        .find_by(id: @confirmation.data.fetch("source_entry_id"))
      unless entry
        @errors = [ "That journal entry does not exist in this workspace." ]
        return self
      end

      draft = Llm::JournalEntryProposal.new(workspace: @chat.workspace, data: reversal_data(entry))
      if draft.invalid?
        @errors = draft.errors
        return self
      end

      @superseded = @chat.proposals.proposed.by_type("journal_entry").to_a
      @superseded.each(&:supersede!)
      @proposal = @chat.proposals.create!(
        workspace: @chat.workspace,
        proposal_type: "journal_entry",
        version: (@chat.proposals.by_type("journal_entry").maximum(:version) || 0) + 1,
        data: draft.data
      )
      @confirmation.update!(
        status: "confirmed",
        data: @confirmation.data.merge("reversal_proposal_id" => @proposal.id)
      )
    end
    self
  end

  private

  def reversal_data(entry)
    {
      "description" => "Reversal of journal entry #{entry.id}: #{entry.description}",
      "entry_date" => (@confirmation.data["use_original_date"] ? entry.entry_date : Date.current).iso8601,
      "amount_source" => "existing_posted_entry",
      "reverses_journal_entry_id" => entry.id,
      "lines" => entry.journal_entry_lines.map do |line|
        {
          "source_line_id" => line.id,
          "account_id" => line.account_id,
          "side" => line.debit_kobo.positive? ? "credit" : "debit",
          "amount_kobo" => line.debit_kobo.positive? ? line.debit_kobo : line.credit_kobo,
          "counterparty_name" => line.counterparty&.name
        }
      end
    }
  end
end

class ProposeEntry < RubyLLM::Tool
  description "Propose a balanced double-entry journal entry using account IDs returned by list_accounts. " \
              "This creates a reviewable proposal only; it never posts an entry. Amounts are in naira."

  params do
    string :description, description: "short, clear description of the transaction"
    string :entry_date, required: false,
                        description: "ISO date (YYYY-MM-DD) the transaction happened; defaults to today"
    array :lines, description: "at least two debit or credit lines that balance" do
      object do
        number :account_id, description: "account ID returned by list_accounts"
        string :side, enum: %w[debit credit], description: "whether this line is a debit or credit"
        string :amount_naira, description: "positive amount in naira as a plain number, e.g. \"4550.50\""
        string :counterparty_name, required: false, description: "person or organisation on the other side"
      end
    end
  end

  def initialize(workspace)
    @workspace = workspace
  end

  def execute(description:, lines:, entry_date: nil)
    draft = Llm::JournalEntryProposal.from_tool(
      workspace: @workspace,
      description: description,
      entry_date: entry_date,
      lines: lines
    )

    return { error: draft.errors.join(", ") } if draft.invalid?

    {
      proposal: true,
      proposed_action: "journal_entry",
      entry_data: draft.data,
      message: "Journal-entry proposal created for review."
    }
  end
end

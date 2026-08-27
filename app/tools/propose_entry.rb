class ProposeEntry < RubyLLM::Tool
  description "Propose a balanced double-entry journal entry using account IDs returned by list_accounts. " \
              "Every required account must already exist. This creates a reviewable proposal only; " \
              "it never posts an entry. Amounts are in naira."

  params do
    string :description, description: "short, clear description of the transaction"
    string :entry_date, required: false,
                        description: "ISO date (YYYY-MM-DD) the transaction happened; defaults to today"
    array :lines, description: "at least two debit or credit lines that balance" do
      object do
        number :account_id, description: "account ID returned by list_accounts"
        string :side, enum: %w[debit credit], description: "whether this line is a debit or credit"
        string :amount_naira, description: "positive amount in naira as a decimal string, e.g. \"4550.50\""
        string :counterparty_name, required: false, description: "person or organisation on the other side"
      end
    end
  end

  def initialize(chat)
    @chat = chat
    @workspace = chat.workspace
  end

  def execute(description:, lines:, entry_date: nil)
    unless account_lookup_for_active_turn?
      return {
        error: "Check the active workspace accounts before proposing an entry.",
        grounding_error: true
      }
    end

    draft = Llm::JournalEntryProposal.from_tool(
      workspace: @workspace,
      description: description,
      entry_date: entry_date,
      lines: lines
    )

    return { error: draft.errors.join(", ") } if draft.invalid?

    grounding = Llm::ProposalGrounding.new(chat: @chat, data: draft.data)
    if grounding.invalid?
      return {
        error: "That proposal is not grounded in the active transaction: #{grounding.errors.join(', ')}.",
        grounding_error: true
      }
    end

    halt({
      proposal: true,
      proposed_action: "journal_entry",
      entry_data: draft.data,
      message: "Journal-entry proposal created for review."
    })
  rescue StandardError => e
    Rails.logger.error("ProposeEntry failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(10).to_a.join("\n")}")
    { error: "I couldn't structure that entry from what you described. Please restate the transaction with explicit naira amounts." }
  end


  private

  def account_lookup_for_active_turn?
    return true unless @chat.respond_to?(:persisted?) && @chat.persisted?

    active_turn = @chat.active_turn
    return true unless active_turn

    Llm::ToolCall.joins(:llm_message)
      .where(name: "list_accounts", llm_messages: { llm_turn_id: active_turn.id })
      .exists?
  end
end

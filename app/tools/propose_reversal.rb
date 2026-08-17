class ProposeReversal < RubyLLM::Tool
  REVERSAL_QUESTION_PATTERN = /\brevers\w*\b.*\?\s*\z/i

  description "Create a reviewable reversing journal-entry proposal for a posted entry in this workspace. It never deletes or changes the original entry."

  params do
    integer :entry_id, description: "posted journal entry ID returned by list_journal_entries"
  end

  def initialize(chat)
    @chat = chat
    @workspace = chat.workspace
  end

  def execute(entry_id:)
    unless confirmation_asked?
      return { error: "I need your confirmation before I prepare a reversal. " \
                      "Please confirm you want to reverse journal entry #{entry_id}." }
    end

    entry = @workspace.journal_entries
      .includes(journal_entry_lines: :account)
      .find_by(id: entry_id)

    return { error: "That journal entry does not exist in this workspace." } unless entry
    return { error: "That journal entry has already been reversed." } if @workspace.journal_entries.where(reverses_journal_entry_id: entry.id).exists?

    {
      proposal: true,
      proposed_action: "journal_entry",
      entry_data: {
        "description" => "Reversal of journal entry #{entry.id}: #{entry.description}",
        "entry_date" => Date.current.to_s,
        "amount_source" => "existing_posted_entry",
        "reverses_journal_entry_id" => entry.id,
        "lines" => entry.journal_entry_lines.map do |line|
          {
            "account_id" => line.account_id,
            "side" => line.debit_kobo.to_i.positive? ? "credit" : "debit",
            "amount_kobo" => line.debit_kobo.to_i.positive? ? line.debit_kobo : line.credit_kobo,
            "counterparty_name" => line.counterparty&.name
          }
        end
      },
      message: "Reversal proposal created for review."
    }
  end

  private

  def confirmation_asked?
    previous = @chat.llm_messages.where(role: "assistant")
      .where.not(content: [ nil, "" ])
      .order(:created_at, :id)
      .last&.content.to_s
    previous.match?(REVERSAL_QUESTION_PATTERN)
  end
end

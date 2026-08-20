class ProposeEntry < RubyLLM::Tool
  description "Propose a balanced double-entry journal entry. Each line uses an account_id returned by " \
              "list_accounts, or an account_name from the recommended catalog when that account does not exist " \
              "yet. This creates a reviewable proposal only; it never posts an entry. Amounts are in naira."

  params do
    string :description, description: "short, clear description of the transaction"
    string :entry_date, required: false,
                        description: "ISO date (YYYY-MM-DD) the transaction happened; defaults to today"
    array :lines, description: "at least two debit or credit lines that balance" do
      object do
        number :account_id, required: false, description: "account ID returned by list_accounts"
        string :account_name, required: false,
                              description: "account name from the recommended catalog when it does not exist yet"
        string :side, enum: %w[debit credit], description: "whether this line is a debit or credit"
        string :amount_naira, description: "positive amount in naira as a decimal string, e.g. \"4550.50\""
        string :counterparty_name, required: false, description: "person or organisation on the other side"
      end
    end
  end

  def initialize(chat)
    @workspace = chat.workspace
  end

  def execute(description:, lines:, entry_date: nil)
    missing = []
    resolved_lines = []
    Array(lines).each do |line|
      resolved = resolve_line(line, missing)
      return resolved if resolved.is_a?(Hash) && resolved[:error]

      resolved_lines << resolved
    end

    return missing_accounts_error(missing) if missing.any?

    draft = Llm::JournalEntryProposal.from_tool(
      workspace: @workspace,
      description: description,
      entry_date: entry_date,
      lines: resolved_lines
    )

    return { error: draft.errors.join(", ") } if draft.invalid?

    {
      proposal: true,
      proposed_action: "journal_entry",
      entry_data: draft.data,
      message: "Journal-entry proposal created for review."
    }
  rescue StandardError => e
    Rails.logger.error("ProposeEntry failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(10).to_a.join("\n")}")
    { error: "I couldn't structure that entry from what you described. Please restate the transaction with explicit naira amounts." }
  end

  private

  def resolve_line(line, missing)
    unless line.is_a?(Hash)
      return { error: "each line must be an object with an account_id or an account_name" }
    end

    line = line.transform_keys(&:to_sym)

    if line[:account_id].present? && line[:account_name].present?
      return { error: "each line must specify either an account_id or an account_name, not both" }
    end

    return line if line[:account_id].present?

    name = line[:account_name].to_s.strip
    return { error: "each line needs an account_id or an account_name" } if name.blank?

    account = @workspace.accounts.find_by("LOWER(name) = LOWER(?)", name)
    return line.merge(account_id: account.id) if account

    spec = @workspace.catalog.recommended.values.find { |candidate| candidate[:name].casecmp?(name) }
    missing << {
      name: name,
      base_type: spec ? spec[:base] : (line[:side] == "debit" ? "expense" : "income")
    }
    nil
  end

  def missing_accounts_error(missing)
    list = missing.uniq { |account| account[:name].downcase }
      .map { |account| "#{account[:name]} (#{account[:base_type]})" }.join(", ")

    {
      error: "I couldn't record this transaction because the necessary accounts to do so are insufficient. " \
             "The accounts that should be created are: #{list}."
    }
  end
end

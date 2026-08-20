class CreateAccount < RubyLLM::Tool
  description "Create an account in this workspace's chart of accounts. " \
              "Use only after the user has explicitly approved creating the account. " \
              "The account becomes available immediately and can be used by propose_entry."

  params do
    string :name, description: "account name, e.g. \"Utilities & Internet\""
    string :base_type, enum: %w[asset liability equity income expense], description: "base type, one of the chart of accounts categories"
    string :account_type, description: "account type valid for the base type"
    string :detail_type, description: "detail type valid for the account type"
  end

  def initialize(workspace)
    @workspace = workspace
  end

  def execute(name:, base_type:, account_type:, detail_type:)
    account = @workspace.accounts.find_by("LOWER(name) = LOWER(?)", name)
    return account_payload(account) if account

    resolved = resolve_taxonomy(base_type, account_type, detail_type)
    return { error: resolved } if resolved.is_a?(String)

    resolved_base, resolved_type, resolved_detail = resolved
    account_payload(
      @workspace.accounts.create!(
        name: name,
        base_type: resolved_base,
        account_type: resolved_type,
        detail_type: resolved_detail
      )
    )
  rescue ActiveRecord::RecordInvalid => e
    { error: e.record.errors.full_messages.join(", ") }
  end

  private

  def account_payload(account)
    {
      account: {
        id: account.id,
        name: account.name,
        base_type: account.base_type,
        account_type: account.account_type,
        detail_type: account.detail_type
      }
    }
  end

  def resolve_taxonomy(base_type, account_type, detail_type)
    categories = @workspace.catalog.chart_of_accounts
    category = categories.find { |candidate| candidate[:category].downcase == base_type }
    return "Unknown base type #{base_type}. Valid base types are: #{categories.map { |candidate| candidate[:category].downcase }.join(", ")}." unless category

    entry = category[:account_types].find { |candidate| candidate[:account_type].casecmp?(account_type) }
    unless entry
      return "Unknown account type #{account_type} for #{base_type}. " \
             "Valid account types are: #{category[:account_types].map { |candidate| candidate[:account_type] }.join(", ")}."
    end

    detail = entry[:detail_types].find { |candidate| candidate.casecmp?(detail_type) }
    return "Unknown detail type #{detail_type} for #{account_type}. Valid detail types are: #{entry[:detail_types].join(", ")}." unless detail

    [ category[:category].downcase, entry[:account_type], detail ]
  end
end

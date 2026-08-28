class ListAccounts < RubyLLM::Tool
  description "Resolve accounts for a transaction. Prefer a suitable existing account. If none fits, prefer a " \
              "recommended catalog account. If no recommendation fits, define a clear account name using the " \
              "returned valid taxonomy. Never substitute an unrelated account or invent an account ID."

  def initialize(workspace)
    @workspace = workspace
  end

  def execute
    existing = @workspace.accounts.ordered.to_a
    existing_taxonomy = existing.map { |account| [ account.base_type, account.account_type, account.detail_type ] }

    {
      existing_accounts: existing.map { |account| account_hash(account) },
      recommended_accounts: @workspace.catalog.recommended.values
        .reject { |spec| existing_taxonomy.include?([ spec[:base], spec[:type], spec[:detail] ]) }
        .map { |spec| recommended_hash(spec) },
      account_taxonomy: taxonomy
    }
  end

  private

  def account_hash(account)
    {
      id: account.id,
      name: account.name,
      base_type: account.base_type,
      account_type: account.account_type,
      detail_type: account.detail_type
    }
  end

  def recommended_hash(spec)
    {
      name: spec[:name],
      base_type: spec[:base],
      account_type: spec[:type],
      detail_type: spec[:detail],
      description: spec[:description]
    }.compact
  end

  def taxonomy
    @workspace.catalog.categories.map do |category|
      {
        base_type: category.fetch(:category).downcase,
        account_types: category.fetch(:account_types).map do |account_type|
          {
            account_type: account_type.fetch(:account_type),
            detail_types: @workspace.catalog.detail_types_for(account_type.fetch(:account_type))
          }
        end
      }
    end
  end
end

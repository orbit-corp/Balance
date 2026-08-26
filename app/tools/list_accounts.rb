class ListAccounts < RubyLLM::Tool
  description "List the ledger accounts that exist in this workspace (use their ids when proposing an entry), " \
              "and the recommended accounts from the workspace's catalog that do not exist yet " \
              "(use their taxonomy when proposing a missing account — never invent an id for them)."

  def initialize(workspace)
    @workspace = workspace
  end

  def execute
    existing = @workspace.accounts.ordered.to_a
    existing_names = existing.map { |account| account.name.downcase }

    {
      existing_accounts: existing.map { |account| account_hash(account) },
      recommended_accounts: @workspace.catalog.recommended.values
        .reject { |spec| existing_names.include?(spec[:name].downcase) }
        .map { |spec| recommended_hash(spec) }
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
      base: spec[:base],
      parent: parent_name(spec)
    }.compact
  end

  def parent_name(spec)
    @workspace.catalog.core[spec[:parent]]&.dig(:name)
  end
end

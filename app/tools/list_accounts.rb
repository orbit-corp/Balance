class ListAccounts < RubyLLM::Tool
  description "List the ledger accounts that exist in this workspace (use their ids when proposing an entry), " \
              "and the recommended accounts from the personal-ledger catalog that do not exist yet " \
              "(reference those only by their account_name — never invent an id for them)."

  def initialize(workspace)
    @workspace = workspace
  end

  def execute
    existing = @workspace.accounts.ordered.to_a
    existing_names = existing.map { |account| account.name.downcase }

    {
      existing_accounts: existing.map { |account| account_hash(account) },
      recommended_accounts: Account::RECOMMENDED
        .reject { |spec| existing_names.include?(spec[:name].downcase) }
        .map { |spec| spec.slice(:name, :base) }
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
end

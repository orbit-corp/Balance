class ListAccounts < RubyLLM::Tool
  description "List the ledger accounts that exist in this workspace, so you know which account ids " \
              "to use when proposing a journal entry."

  def initialize(workspace)
    @workspace = workspace
  end

  def execute
    @workspace.accounts.ordered.map do |account|
      {
        id: account.id,
        name: account.name,
        base_type: account.base_type,
        account_type: account.account_type,
        detail_type: account.detail_type
      }
    end
  end
end

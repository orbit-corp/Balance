require "test_helper"

class ListAccountsTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @cash = Account.for_role!(@workspace, :cash)
  end

  test "returns existing accounts with ids and recommended accounts that do not exist yet" do
    result = ListAccounts.new(@workspace).execute

    existing = result[:existing_accounts]
    assert_includes existing.map { |account| account[:id] }, @cash.id
    assert_includes existing.map { |account| account[:name] }, "Cash"

    recommended = result[:recommended_accounts]
    assert_includes recommended, {
      name: "Earned Salary & Wages", base_type: "income", account_type: "Personal Inflows",
      detail_type: "Earned Salary & Wages",
      description: "Money received from employment, personal activities, investments, or other sources."
    }
    assert_includes recommended, {
      name: "Living & Daily Needs", base_type: "expense", account_type: "Personal Outflows",
      detail_type: "Living & Daily Needs",
      description: "Money spent on living costs, financial obligations, and personal activities."
    }
    refute_includes recommended.map { |account| account[:name] }, "Cash"

    personal_outflows = result[:account_taxonomy]
      .find { |category| category[:base_type] == "expense" }
      .fetch(:account_types)
      .find { |account_type| account_type[:account_type] == "Personal Outflows" }
    assert_includes personal_outflows[:detail_types], "Financial Expenses"
  end

  test "drops recommended accounts that already exist" do
    @workspace.accounts.create!(
      name: "Salary & Wages",
      base_type: "income",
      account_type: "Personal Inflows",
      detail_type: "Earned Salary & Wages"
    )

    result = ListAccounts.new(@workspace).execute

    refute_includes result[:recommended_accounts].map { |account| account[:detail_type] }, "Earned Salary & Wages"
    assert_includes result[:existing_accounts].map { |account| account[:name] }, "Salary & Wages"
  end
end

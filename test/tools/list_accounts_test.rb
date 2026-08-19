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
    assert_includes recommended, { name: "Salary Income", base: "income" }
    assert_includes recommended, { name: "Pension", base: "expense" }
    refute_includes recommended.map { |account| account[:name] }, "Cash"
  end

  test "drops recommended accounts that already exist" do
    Account.for_role!(@workspace, :other_income).update!(name: "Salary Income")

    result = ListAccounts.new(@workspace).execute

    refute_includes result[:recommended_accounts].map { |account| account[:name] }, "Salary Income"
    assert_includes result[:existing_accounts].map { |account| account[:name] }, "Salary Income"
  end
end

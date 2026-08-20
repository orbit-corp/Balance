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
    assert_includes existing.map { |account| account[:name] }, "Cash & Bank"

    recommended = result[:recommended_accounts]
    assert_includes recommended, { name: "Salary & Wages", base: "income", parent: "Income" }
    assert_includes recommended, { name: "Groceries & Food", base: "expense", parent: "Expenses" }
    refute_includes recommended.map { |account| account[:name] }, "Cash & Bank"
  end

  test "drops recommended accounts that already exist" do
    Account.for_role!(@workspace, :primary_income).update!(name: "Salary & Wages")

    result = ListAccounts.new(@workspace).execute

    refute_includes result[:recommended_accounts].map { |account| account[:name] }, "Salary & Wages"
    assert_includes result[:existing_accounts].map { |account| account[:name] }, "Salary & Wages"
  end
end

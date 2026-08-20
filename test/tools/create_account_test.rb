require "test_helper"

class CreateAccountTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
  end

  def create_account(**overrides)
    CreateAccount.new(@workspace).execute(
      name: "Utilities & Internet",
      base_type: "expense",
      account_type: "Personal Outflows",
      detail_type: "Housing & Utilities",
      **overrides
    )
  end

  test "creates an account with a valid catalog path" do
    result = create_account

    assert result[:account]
    account = @workspace.accounts.find(result.dig(:account, :id))
    assert_equal "Utilities & Internet", account.name
    assert_equal "expense", account.base_type
    assert_equal "Personal Outflows", account.account_type
    assert_equal "Housing & Utilities", account.detail_type
  end

  test "resolves case-inconsistent catalog values to their canonical form" do
    result = create_account(account_type: "personal outflows", detail_type: "housing & utilities")

    account = @workspace.accounts.find(result.dig(:account, :id))
    assert_equal "Personal Outflows", account.account_type
    assert_equal "Housing & Utilities", account.detail_type
  end

  test "returns the existing account instead of duplicating, case-insensitively" do
    first = create_account
    second = create_account(name: "utilities & internet")

    assert_equal first[:account][:id], second[:account][:id]
    assert_equal 1, @workspace.accounts.count
  end

  test "returns an actionable error for an unknown detail type" do
    result = create_account(detail_type: "made_up")

    assert result[:error]
    assert_includes result[:error], "made_up"
    assert_includes result[:error], "Housing & Utilities"
  end

  test "returns an actionable error for an unknown account type" do
    result = create_account(account_type: "made_up")

    assert result[:error]
    assert_includes result[:error], "made_up"
    assert_includes result[:error], "Valid account types are: Personal Outflows."
  end

  test "returns an actionable error for an unknown base type" do
    result = create_account(base_type: "made_up")

    assert result[:error]
    assert_includes result[:error], "made_up"
    assert_includes result[:error], "income"
  end

  test "creates accounts only in the given workspace" do
    other = workspaces(:bola_shop)

    create_account
    CreateAccount.new(other).execute(
      name: "Groceries & Food",
      base_type: "expense",
      account_type: "Personal Outflows",
      detail_type: "Living & Daily Needs"
    )

    assert_equal 1, @workspace.accounts.count
    assert_equal 1, other.accounts.count
  end
end

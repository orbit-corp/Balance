require "test_helper"

class AccountTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
  end

  test "accepts a valid catalog path" do
    account = @workspace.accounts.build(
      name: "Checking",
      base_type: "asset",
      account_type: "Cash & Liquid Assets",
      detail_type: "Checking Account"
    )

    assert account.valid?
  end

  test "rejects an unknown base type" do
    account = @workspace.accounts.build(
      name: "Checking",
      base_type: "magic",
      account_type: "Cash & Liquid Assets",
      detail_type: "Checking Account"
    )

    refute account.valid?
    assert_includes account.errors[:base_type], "is not a valid base type"
  end

  test "rejects an account type that does not belong to its base type" do
    account = @workspace.accounts.build(
      name: "Checking",
      base_type: "liability",
      account_type: "Cash & Liquid Assets",
      detail_type: "Checking Account"
    )

    refute account.valid?
    assert_includes account.errors[:account_type], "is not valid for base type liability"
  end

  test "rejects a detail type that does not belong to its account type" do
    account = @workspace.accounts.build(
      name: "Checking",
      base_type: "asset",
      account_type: "Cash & Liquid Assets",
      detail_type: "Mortgage"
    )

    refute account.valid?
    assert_includes account.errors[:detail_type], "is not valid for account type Cash & Liquid Assets"
  end
end

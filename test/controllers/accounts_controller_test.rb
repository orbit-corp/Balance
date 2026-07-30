require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
    Ledger::ChartOfAccounts.seed!(@workspace)
  end

  test "lists money accounts with their balances" do
    post_transaction!(@workspace, kind: :income, amount_kobo: 4_000_00, category: "Sales", occurred_on: Date.current)

    get accounts_path

    assert_response :success
    assert_select "body", /Cash/
    assert_select "body", /#{Regexp.escape("₦4,000.00")}/
  end

  test "renames a money account" do
    cash = @workspace.accounts.asset.find_by!(name: "Bank")

    patch account_path(cash), params: { account: { name: "GTBank" } }

    assert_redirected_to accounts_path
    assert_equal "GTBank", cash.reload.name
  end

  test "cannot rename another workspace's account" do
    other_workspace = workspaces(:bola_shop)
    Ledger::ChartOfAccounts.seed!(other_workspace)
    foreign = other_workspace.accounts.asset.first

    patch account_path(foreign), params: { account: { name: "Hijacked" } }

    assert_response :not_found
    assert_not_equal "Hijacked", foreign.reload.name
  end

  test "cannot rename a category account through this screen" do
    sales = @workspace.accounts.income.find_by!(name: "Sales")

    patch account_path(sales), params: { account: { name: "Renamed" } }

    assert_response :not_found
    assert_equal "Sales", sales.reload.name
  end

  test "requires authentication" do
    delete session_path
    get accounts_path

    assert_redirected_to new_session_path
  end
end

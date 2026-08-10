require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
  end

  test "lists accounts for the current workspace" do
    cash = Account.for_role!(@workspace, :cash)

    get accounts_path

    assert_response :success
    assert_select "body", /#{Regexp.escape(cash.name)}/
  end

  test "creates an account" do
    post accounts_path, params: { account: { name: "GTBank", base_type: "asset", account_type: "bank", detail_type: "checking" } }

    assert_redirected_to accounts_path
    assert @workspace.accounts.exists?(name: "GTBank")
  end

  test "renames a core account" do
    cash = Account.for_role!(@workspace, :cash)

    patch account_path(cash), params: { account: { name: "GTBank" } }

    assert_redirected_to accounts_path
    assert_equal "GTBank", cash.reload.name
  end

  test "cannot change a core account's base type" do
    cash = Account.for_role!(@workspace, :cash)

    patch account_path(cash), params: { account: { base_type: "liability" } }

    assert_equal "asset", cash.reload.base_type
  end

  test "cannot rename another workspace's account" do
    other_workspace = workspaces(:bola_shop)
    foreign = Account.for_role!(other_workspace, :cash)

    patch account_path(foreign), params: { account: { name: "Hijacked" } }

    assert_response :not_found
    assert_not_equal "Hijacked", foreign.reload.name
  end

  test "requires authentication" do
    delete session_path
    get accounts_path

    assert_redirected_to new_session_path
  end
end

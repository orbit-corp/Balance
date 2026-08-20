require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
  end

  def create_account(**attributes)
    @workspace.accounts.create!(
      { name: "Cash", base_type: "asset", account_type: "Cash & Liquid Assets", detail_type: "Checking Account" }
        .merge(attributes)
    )
  end

  test "lists accounts for the current workspace" do
    cash = create_account(name: "Kuda")

    get accounts_path

    assert_response :success
    assert_select "body", /#{Regexp.escape(cash.name)}/
  end

  test "new renders account types grouped by category" do
    get new_account_path

    assert_response :success
    assert_select "optgroup[label='ASSET'] option", text: "Cash & Liquid Assets"
    assert_select "optgroup[label='EXPENSE'] option", text: "Personal Outflows"
  end

  test "creates an account" do
    post accounts_path,
         params: { account: { name: "GTBank", base_type: "asset", account_type: "Cash & Liquid Assets", detail_type: "Checking Account" } }

    assert_redirected_to accounts_path
    assert @workspace.accounts.exists?(name: "GTBank")
  end

  test "renames an account" do
    cash = create_account

    patch account_path(cash), params: { account: { name: "GTBank" } }

    assert_redirected_to accounts_path
    assert_equal "GTBank", cash.reload.name
  end

  test "cannot move an account to an incompatible base type" do
    cash = create_account

    patch account_path(cash), params: { account: { base_type: "liability" } }

    assert_equal "asset", cash.reload.base_type
  end

  test "cannot rename another workspace's account" do
    other_workspace = workspaces(:bola_shop)
    foreign = other_workspace.accounts.create!(
      name: "Cash",
      base_type: "asset",
      account_type: "Cash & Liquid Assets",
      detail_type: "Checking Account"
    )

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

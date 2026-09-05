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
    assert_select "button[aria-label='Actions for Kuda']"
  end

  test "shows a lock instead of actions for system accounts" do
    system_account = create_account(name: "Bank Account", role: "bank")

    get accounts_path

    assert_select "tr##{dom_id(system_account)} [title='System account — locked']"
    assert_select "tr##{dom_id(system_account)} button[aria-label^='Actions']", count: 0
  end

  test "new renders account types grouped by category" do
    get new_account_path

    assert_response :success
    assert_select "optgroup[label='ASSET'] option", text: "Cash & Liquid Assets"
    assert_select "optgroup[label='EXPENSE'] option", text: "Personal Outflows"
    assert_select "[data-controller='select-menu'][data-select-menu-searchable-value='true']", count: 2
    assert_select "[data-controller='select-menu'][data-select-menu-search-in-trigger-value='true'] input[role='combobox']", count: 2
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

  test "edits an account in a modal" do
    cash = create_account

    get edit_account_path(cash)

    assert_response :success
    assert_select "turbo-frame#modal"
    assert_select "form[action='#{account_path(cash)}']"
    assert_select "select#account_account_type option[selected]", text: "Cash & Liquid Assets"
  end

  test "deletes a custom account" do
    cash = create_account

    assert_difference("Account.count", -1) do
      delete account_path(cash)
    end

    assert_redirected_to accounts_path
  end

  test "does not delete a system account" do
    system_account = create_account(role: "cash")

    assert_no_difference("Account.count") do
      delete account_path(system_account)
    end

    assert_redirected_to accounts_path
    assert_equal "This account cannot be deleted.", flash[:alert]
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

  test "cannot delete another workspace's account" do
    foreign = workspaces(:bola_shop).accounts.create!(
      name: "Cash",
      base_type: "asset",
      account_type: "Cash & Liquid Assets",
      detail_type: "Checking Account"
    )

    delete account_path(foreign)

    assert_response :not_found
    assert Account.exists?(foreign.id)
  end

  test "requires authentication" do
    delete session_path
    get accounts_path

    assert_redirected_to new_session_path
  end
end

require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
  end

  test "shows today, week, and month totals reflecting recorded entries" do
    cash = Account.for_role!(@workspace, :cash)
    other_income = Account.for_role!(@workspace, :primary_income)
    rent = @workspace.accounts.create!(name: "Rent Expense", base_type: "expense", account_type: "expense", detail_type: "rent_or_lease_of_buildings")

    post_journal_entry!(@workspace, debit_account: cash, credit_account: other_income, amount_kobo: 500_00)
    post_journal_entry!(@workspace, debit_account: rent, credit_account: cash, amount_kobo: 200_00)

    get dashboard_path
    assert_response :success
    assert_select "body", /#{Regexp.escape("₦500.00")}/
    assert_select "body", /#{Regexp.escape("₦200.00")}/
    assert_select "body", /#{Regexp.escape("₦300.00")}/
  end

  test "shows empty state when there are no journal entries" do
    get dashboard_path
    assert_response :success
    assert_select "body", /Nothing recorded yet/
  end
end

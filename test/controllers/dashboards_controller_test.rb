require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
  end

  test "shows today, week, and month totals reflecting recorded transactions" do
    post_transaction!(@workspace, kind: :income, amount_kobo: 500_00, category: "Sales", occurred_on: Date.current)
    post_transaction!(@workspace, kind: :expense, amount_kobo: 200_00, category: "Restock", occurred_on: Date.current)

    get dashboard_path
    assert_response :success
    assert_select "body", /#{Regexp.escape("₦500.00")}/
    assert_select "body", /#{Regexp.escape("₦200.00")}/
    assert_select "body", /#{Regexp.escape("₦300.00")}/
  end

  test "shows empty state when there are no transactions" do
    get dashboard_path
    assert_response :success
    assert_select "body", /Log your first sale/
  end
end

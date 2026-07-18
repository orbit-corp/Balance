require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    Category.seed_defaults_for(@workspace)
    sign_in_as(@user)
  end

  test "shows today, week, and month totals reflecting recorded transactions" do
    sales = @workspace.categories.income.find_by(name: "Sales")
    restock = @workspace.categories.expense.find_by(name: "Restock")

    @workspace.transactions.create!(kind: :income, amount_kobo: 500_00, category: sales, occurred_on: Date.current)
    @workspace.transactions.create!(kind: :expense, amount_kobo: 200_00, category: restock, occurred_on: Date.current)

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

require "test_helper"

class GetBalanceSummaryTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @cash = Account.for_role!(@workspace, :cash)
    @expense = Account.for_role!(@workspace, :other_expense)
    post_journal_entry!(
      @workspace,
      debit_account: @expense,
      credit_account: @cash,
      amount_kobo: 250_000,
      entry_date: Date.current
    )
  end

  test "returns today, this week, this month, and account balances" do
    result = GetBalanceSummary.new(@workspace).execute

    assert_equal [ "Today", "This week", "This month" ], result[:periods].keys
    assert_equal "0.00", result.dig(:periods, "Today", :income_naira)
    assert_equal "2500.00", result.dig(:periods, "Today", :expense_naira)
    assert_equal "-2500.00", result.dig(:periods, "Today", :net_naira)
    assert_includes result[:account_balances].map { |balance| balance[:account] }, "Cash"
  end

  test "ignores entries from other workspaces" do
    other_workspace = workspaces(:bola_shop)
    other_cash = Account.for_role!(other_workspace, :cash)
    other_expense = Account.for_role!(other_workspace, :other_expense)
    post_journal_entry!(
      other_workspace,
      debit_account: other_expense,
      credit_account: other_cash,
      amount_kobo: 500_000,
      entry_date: Date.current
    )

    result = GetBalanceSummary.new(@workspace).execute

    assert_equal "2500.00", result.dig(:periods, "Today", :expense_naira)
    refute result[:account_balances].any? { |balance| balance[:balance_naira] == "5000.00" }
  end
end

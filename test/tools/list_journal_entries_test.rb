require "test_helper"

class ListJournalEntriesTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @cash = Account.for_role!(@workspace, :cash)
    @expense = Account.for_role!(@workspace, :uncategorized_expense)
  end

  test "returns posted entries from the current workspace" do
    entry = post_journal_entry!(
      @workspace,
      debit_account: @expense,
      credit_account: @cash,
      amount_kobo: 250_000,
      entry_date: Date.new(2026, 8, 12)
    )

    result = ListJournalEntries.new(@workspace).execute

    assert_equal [ entry.id ], result.map { |item| item[:id] }
    assert_equal "2500.00", result.first[:lines].find { |line| line[:debit_naira] != "0.00" }[:debit_naira]
  end

  test "filters by inclusive date range" do
    post_journal_entry!(@workspace, debit_account: @expense, credit_account: @cash, amount_kobo: 100, entry_date: Date.new(2026, 8, 10))
    post_journal_entry!(@workspace, debit_account: @expense, credit_account: @cash, amount_kobo: 200, entry_date: Date.new(2026, 8, 12))

    result = ListJournalEntries.new(@workspace).execute(from_date: "2026-08-12", to_date: "2026-08-12")

    assert_equal [ "2026-08-12" ], result.map { |item| item[:date] }
  end

  test "rejects an invalid date range" do
    result = ListJournalEntries.new(@workspace).execute(from_date: "2026-08-13", to_date: "2026-08-12")

    assert_equal "from_date cannot be after to_date", result[:error]
  end

  test "does not return entries from other workspaces" do
    other_workspace = workspaces(:bola_shop)
    other_cash = Account.for_role!(other_workspace, :cash)
    other_expense = Account.for_role!(other_workspace, :uncategorized_expense)
    post_journal_entry!(
      other_workspace,
      debit_account: other_expense,
      credit_account: other_cash,
      amount_kobo: 250_000,
      entry_date: Date.new(2026, 8, 12)
    )

    assert_empty ListJournalEntries.new(@workspace).execute
  end

  test "marks entries that are themselves reversals via reverses_journal_entry_id" do
    entry = post_journal_entry!(
      @workspace,
      debit_account: @expense,
      credit_account: @cash,
      amount_kobo: 250_000,
      entry_date: Date.new(2026, 8, 12)
    )
    reversal = entry.reverse!

    result = ListJournalEntries.new(@workspace).execute

    assert_nil result.find { |item| item[:id] == entry.id }[:reverses_journal_entry_id]
    assert_equal entry.id, result.find { |item| item[:id] == reversal.id }[:reverses_journal_entry_id]
  end
end

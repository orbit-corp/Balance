require "test_helper"

class LedgerIntegrityCheckJobTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @cash = Account.for_role!(@workspace, :cash)
    @expense = Account.for_role!(@workspace, :general_expense)
  end

  test "passes for a balanced ledger" do
    post_journal_entry!(
      @workspace,
      debit_account: @expense,
      credit_account: @cash,
      amount_kobo: 250_000
    )

    assert_nothing_raised { LedgerIntegrityCheckJob.perform_now }
  end

  test "raises for an unbalanced entry" do
    entry = post_journal_entry!(
      @workspace,
      debit_account: @expense,
      credit_account: @cash,
      amount_kobo: 250_000
    )
    entry.journal_entry_lines.where(debit_kobo: 250_000).update_all(debit_kobo: 200_000)

    error = assert_raises(RuntimeError) { LedgerIntegrityCheckJob.perform_now }
    assert_includes error.message, entry.id.to_s
  end
end

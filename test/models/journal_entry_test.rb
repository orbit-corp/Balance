require "test_helper"

class JournalEntryTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @cash = create_account("Cash", "asset", "Cash & Liquid Assets", "Checking Account")
    @expense = create_account("General Expense", "expense", "Personal Outflows", "Living & Daily Needs")
    @entry = post_journal_entry!(
      @workspace,
      debit_account: @expense,
      credit_account: @cash,
      amount_kobo: 250_000
    )
  end

  test "posted entries are immutable" do
    @entry.description = "Rewritten"

    assert_no_changes -> { @entry.reload.description } do
      assert_not @entry.save
    end
  end

  test "posted entries cannot be destroyed" do
    assert_no_difference "JournalEntry.count" do
      assert_not @entry.destroy
    end
  end

  test "posted lines cannot be changed or destroyed" do
    line = @entry.journal_entry_lines.first

    assert_no_changes -> { line.reload.debit_kobo } do
      line.debit_kobo += 100
      assert_not line.save
    end

    assert_no_difference "JournalEntryLine.count" do
      assert_not line.destroy
    end
  end

  test "reverse! creates a balanced reversal with flipped sides" do
    reversal = nil

    assert_difference "JournalEntry.count", 1 do
      reversal = @entry.reverse!
    end

    assert_equal @entry.id, reversal.reverses_journal_entry_id
    assert_equal 2, reversal.journal_entry_lines.size
    assert_equal reversal.journal_entry_lines.sum(&:debit_kobo), reversal.journal_entry_lines.sum(&:credit_kobo)

    cash_line = reversal.journal_entry_lines.find { |line| line.account_id == @cash.id }
    expense_line = reversal.journal_entry_lines.find { |line| line.account_id == @expense.id }
    assert_equal 250_000, cash_line.debit_kobo
    assert_equal 250_000, expense_line.credit_kobo
  end

  test "cannot reverse an entry that is itself a reversal" do
    reversal = @entry.reverse!

    re_reversal = @workspace.journal_entries.build(
      entry_date: Date.current,
      description: "Reversal of the reversal",
      reverses_journal_entry: reversal,
      journal_entry_lines_attributes: [
        { account_id: @expense.id, debit_kobo: 250_000 },
        { account_id: @cash.id, credit_kobo: 250_000 }
      ]
    )

    assert_not re_reversal.valid?
    assert_includes re_reversal.errors[:reverses_journal_entry], "cannot reverse an entry that is itself a reversal"
  end

  test "rejects a reversal that is not an exact mirror" do
    reversal = @workspace.journal_entries.build(
      entry_date: Date.current,
      description: "Incorrect reversal",
      reverses_journal_entry: @entry,
      journal_entry_lines_attributes: [
        { account_id: @cash.id, debit_kobo: 200_000 },
        { account_id: @expense.id, credit_kobo: 200_000 }
      ]
    )

    assert_not reversal.valid?
    assert_includes reversal.errors[:base], "A reversal must exactly mirror every line of the original entry"
  end

  test "an entry can only be reversed once" do
    @entry.reverse!
    duplicate = @workspace.journal_entries.build(
      entry_date: Date.current,
      description: "Duplicate reversal",
      reverses_journal_entry: @entry,
      journal_entry_lines_attributes: [
        { account_id: @cash.id, debit_kobo: 250_000 },
        { account_id: @expense.id, credit_kobo: 250_000 }
      ]
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:reverses_journal_entry], "has already been reversed"
  end

  test "cannot reference an entry from another workspace as its reversal" do
    other_workspace = workspaces(:bola_shop)
    other_cash = create_account("Cash", "asset", "Cash & Liquid Assets", "Checking Account", workspace: other_workspace)
    other_expense = create_account("General Expense", "expense", "Personal Outflows", "Living & Daily Needs", workspace: other_workspace)
    other_entry = post_journal_entry!(
      other_workspace,
      debit_account: other_expense,
      credit_account: other_cash,
      amount_kobo: 250_000
    )

    entry = @workspace.journal_entries.build(
      entry_date: Date.current,
      description: "Reversal of a foreign entry",
      reverses_journal_entry: other_entry,
      journal_entry_lines_attributes: [
        { account_id: @expense.id, debit_kobo: 250_000 },
        { account_id: @cash.id, credit_kobo: 250_000 }
      ]
    )

    assert_not entry.valid?
    assert_includes entry.errors[:reverses_journal_entry], "must belong to the same workspace as the entry"
  end

  test "requires a description" do
    entry = @workspace.journal_entries.build(
      entry_date: Date.current,
      journal_entry_lines_attributes: [
        { account_id: @expense.id, debit_kobo: 250_000 },
        { account_id: @cash.id, credit_kobo: 250_000 }
      ]
    )

    assert_not entry.valid?
    assert_includes entry.errors[:description], "can't be blank"
  end

  test "rejects entry dates in the future or too far in the past" do
    future = build_entry(entry_date: Date.current + 1.day)
    ancient = build_entry(entry_date: 11.years.ago.to_date)

    assert_not future.valid?
    assert_includes future.errors[:entry_date], "cannot be in the future"
    assert_not ancient.valid?
    assert_includes ancient.errors[:entry_date], "is too far in the past"
  end

  test "rejects the same account on both sides" do
    entry = build_entry(
      lines: [
        { account_id: @cash.id, debit_kobo: 250_000 },
        { account_id: @cash.id, credit_kobo: 250_000 }
      ]
    )

    assert_not entry.valid?
    assert_includes entry.errors[:base], "Account(s) used on both sides: #{@cash.id}"
  end

  test "rejects duplicate identical lines" do
    entry = build_entry(
      lines: [
        { account_id: @cash.id, debit_kobo: 250_000 },
        { account_id: @cash.id, debit_kobo: 250_000 },
        { account_id: @expense.id, credit_kobo: 500_000 }
      ]
    )

    assert_not entry.valid?
    assert_includes entry.errors[:base], "duplicate journal lines are not allowed"
  end

  test "accepts income received against cash" do
    income = create_account("Salary", "income", "Personal Inflows", "Earned Salary & Wages")

    entry = build_entry(
      lines: [
        { account_id: @cash.id, debit_kobo: 90_000 },
        { account_id: income.id, credit_kobo: 90_000 }
      ]
    )

    assert entry.valid?
  end

  test "accepts a liability settled against an expense credit (accrual reversal pattern)" do
    payable = create_account("Accounts Payable", "liability", "Short-Term Debt", "Short-Term Loans")

    entry = build_entry(
      lines: [
        { account_id: payable.id, debit_kobo: 40_000 },
        { account_id: @expense.id, credit_kobo: 40_000 }
      ]
    )

    assert entry.valid?
  end

  test "reversals are valid even though they flip the sides of the original" do
    reversal = nil

    assert_difference "JournalEntry.count", 1 do
      reversal = @entry.reverse!
    end

    cash_line = reversal.journal_entry_lines.find { |line| line.account_id == @cash.id }
    expense_line = reversal.journal_entry_lines.find { |line| line.account_id == @expense.id }

    assert cash_line.debit_kobo.positive?
    assert expense_line.credit_kobo.positive?
    assert reversal.valid?
  end

  test "rejects unbalanced entries before they reach the database" do
    assert_no_difference "JournalEntry.count" do
      entry = build_entry(
        lines: [
          { account_id: @expense.id, debit_kobo: 100_000 },
          { account_id: @cash.id, credit_kobo: 90_000 }
        ]
      )

      assert_not entry.valid?
      assert_includes entry.errors[:base], "Total debits (1000.00) must equal total credits (900.00)"
    end
  end

  private

  def create_account(name, base_type, account_type, detail_type, workspace: @workspace)
    workspace.accounts.create!(
      name: name,
      base_type: base_type,
      account_type: account_type,
      detail_type: detail_type
    )
  end

  def build_entry(entry_date: Date.current, lines: nil)
    lines ||= [
      { account_id: @expense.id, debit_kobo: 250_000 },
      { account_id: @cash.id, credit_kobo: 250_000 }
    ]

    @workspace.journal_entries.build(
      entry_date: entry_date,
      description: "Test entry",
      journal_entry_lines_attributes: lines
    )
  end
end

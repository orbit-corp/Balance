require "test_helper"

class Accounting::PostingServiceTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @cash = create_account("Posting Cash", "asset", "Cash & Liquid Assets", "Checking Account")
    @expense = create_account("Posting Expense", "expense", "Personal Outflows", "Living & Daily Needs")
  end

  test "persists an engine-approved entry and returns its proof" do
    entry = build_entry(debit_kobo: 25_000, credit_kobo: 25_000)

    assert_difference "JournalEntry.count", 1 do
      result = Accounting::PostingService.call(entry: entry)

      assert result.success?, result.errors.join(" ")
      assert result.proof.balanced?
      assert_equal :reallocation, result.proof.relationships.first.law
    end
  end

  test "returns engine errors without persisting an invalid entry" do
    entry = build_entry(debit_kobo: 25_000, credit_kobo: 20_000)

    assert_no_difference "JournalEntry.count" do
      result = Accounting::PostingService.call(entry: entry)

      refute result.success?
      assert_includes result.errors, "Total debits (250.00) must equal total credits (200.00)"
      assert entry.new_record?
    end
  end

  test "locks the original entry before posting its reversal" do
    original = Accounting::PostingService.call(entry: build_entry(debit_kobo: 25_000, credit_kobo: 25_000)).entry
    reversal = @workspace.journal_entries.build(
      description: "Reverse posting test",
      entry_date: Date.current,
      reverses_journal_entry: original,
      journal_entry_lines_attributes: [
        { account: @cash, debit_kobo: 25_000 },
        { account: @expense, credit_kobo: 25_000 }
      ]
    )
    locked = false

    original.stub(:lock!, -> { locked = true; original }) do
      assert Accounting::PostingService.call(entry: reversal).success?
    end

    assert locked
  end

  private

  def create_account(name, base_type, account_type, detail_type)
    @workspace.accounts.create!(
      name: name,
      base_type: base_type,
      account_type: account_type,
      detail_type: detail_type
    )
  end

  def build_entry(debit_kobo:, credit_kobo:)
    @workspace.journal_entries.build(
      description: "Posting service test",
      entry_date: Date.current,
      journal_entry_lines_attributes: [
        { account: @expense, debit_kobo: debit_kobo },
        { account: @cash, credit_kobo: credit_kobo }
      ]
    )
  end
end

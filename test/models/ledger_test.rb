require "test_helper"

class LedgerTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    Ledger::ChartOfAccounts.seed!(@workspace)
    @cash = @workspace.accounts.asset.find_by!(name: "Cash")
  end

  test "a draft needs only an amount and a direction" do
    draft = @workspace.transactions.new(kind: :income, amount_kobo: 5_000_00, occurred_on: Date.current, status: :draft)

    assert_predicate draft, :valid?
    assert draft.save
    assert_nil draft.category
    assert_nil draft.account_id
  end

  test "a posted entry demands a category and a money account" do
    posted = @workspace.transactions.new(kind: :income, amount_kobo: 5_000_00, occurred_on: Date.current, status: :posted)

    assert_not_predicate posted, :valid?
    assert_includes posted.errors.attribute_names, :category
    assert_includes posted.errors.attribute_names, :account
  end

  test "a posted entry rejects a category that does not belong to its kind" do
    posted = @workspace.transactions.new(kind: :income, amount_kobo: 100, category: "Restock", account: @cash, occurred_on: Date.current, status: :posted)

    assert_not_predicate posted, :valid?
    assert_includes posted.errors.attribute_names, :category
  end

  test "a draft holds no postings so it reaches no total or balance" do
    before = LedgerSummary.new(@workspace).this_month.profit_kobo
    draft = @workspace.transactions.create!(kind: :expense, amount_kobo: 9_999_00, occurred_on: Date.current, status: :draft)

    assert_empty draft.postings
    assert_equal before, LedgerSummary.new(@workspace).this_month.profit_kobo
    assert_equal 0, LedgerSummary.new(@workspace).balances.sum(&:amount_kobo)
  end

  test "posting an income entry debits the money account and credits the category" do
    entry = post_entry(kind: :income, amount_kobo: 15_000_00, category: "Sales")
    sales = @workspace.accounts.income.find_by!(name: "Sales")

    assert_predicate entry, :posted?
    assert_equal 2, entry.postings.count
    assert_equal 15_000_00, entry.postings.find_by!(account: @cash).amount_kobo
    assert_equal(-15_000_00, entry.postings.find_by!(account: sales).amount_kobo)
    assert_predicate entry, :postings_balanced?
  end

  test "posting an expense debits the category and credits the money account" do
    entry = post_entry(kind: :expense, amount_kobo: 3_200_00, category: "Transport")
    transport = @workspace.accounts.expense.find_by!(name: "Transport")

    assert_equal 3_200_00, entry.postings.find_by!(account: transport).amount_kobo
    assert_equal(-3_200_00, entry.postings.find_by!(account: @cash).amount_kobo)
    assert_predicate entry, :postings_balanced?
  end

  test "posting fills a missing category and account rather than refusing" do
    draft = @workspace.transactions.create!(kind: :expense, amount_kobo: 800_00, occurred_on: Date.current, status: :draft)

    Ledger::Poster.call(draft)

    assert_predicate draft, :posted?
    assert_predicate draft, :uncategorised?
    assert_equal "Cash", draft.account.name
    assert_predicate draft, :postings_balanced?
  end

  test "every posting in a workspace sums to zero" do
    post_entry(kind: :income, amount_kobo: 15_000_00, category: "Sales")
    post_entry(kind: :expense, amount_kobo: 3_200_00, category: "Transport")

    assert_equal 0, Posting.joins(:recorded_transaction).where(transactions: { workspace_id: @workspace.id }).sum(:amount_kobo)
  end

  test "totals and balances are read from postings" do
    post_entry(kind: :income, amount_kobo: 15_000_00, category: "Sales")
    post_entry(kind: :expense, amount_kobo: 3_200_00, category: "Transport")
    summary = LedgerSummary.new(@workspace)

    assert_equal 15_000_00, summary.this_month.income_kobo
    assert_equal 3_200_00, summary.this_month.expense_kobo
    assert_equal 11_800_00, summary.this_month.profit_kobo
    # The accounting identity: money on hand equals what was earned less what was spent.
    assert_equal summary.this_month.profit_kobo, summary.balances.sum(&:amount_kobo)
  end

  test "re-posting an entry replaces its postings instead of stacking them" do
    entry = post_entry(kind: :income, amount_kobo: 15_000_00, category: "Sales")

    entry.update!(amount_kobo: 20_000_00)
    Ledger::Poster.call(entry)

    assert_equal 2, entry.postings.reload.count
    assert_equal 20_000_00, LedgerSummary.new(@workspace).this_month.income_kobo
  end

  test "an entry cannot use another workspace's money account" do
    other = workspaces(:bola_shop)
    Ledger::ChartOfAccounts.seed!(other)
    foreign_cash = other.accounts.asset.find_by!(name: "Cash")

    entry = @workspace.transactions.new(kind: :income, amount_kobo: 100, category: "Sales", account: foreign_cash, occurred_on: Date.current, status: :posted)

    assert_not_predicate entry, :valid?
    assert_includes entry.errors.attribute_names, :account
  end

  test "an entry cannot post against a category account instead of a money account" do
    sales = @workspace.accounts.income.find_by!(name: "Sales")
    entry = @workspace.transactions.new(kind: :income, amount_kobo: 100, category: "Sales", account: sales, occurred_on: Date.current, status: :posted)

    assert_not_predicate entry, :valid?
    assert_includes entry.errors.attribute_names, :account
  end

  test "seeding the chart of accounts twice does not duplicate accounts" do
    assert_no_difference "Account.count" do
      Ledger::ChartOfAccounts.seed!(@workspace)
    end
  end

  private
    def post_entry(kind:, amount_kobo:, category:)
      transaction = @workspace.transactions.create!(
        kind: kind, amount_kobo: amount_kobo, category: category,
        account: @cash, occurred_on: Date.current, status: :draft
      )
      Ledger::Poster.call(transaction)
    end
end

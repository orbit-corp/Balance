require "test_helper"

class ExpenseTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @bank = create_account(name: "Checking", base_type: "asset", account_type: "Cash & Liquid Assets", detail_type: "Checking Account")
    @fuel = create_account(name: "Fuel", base_type: "expense", account_type: "Personal Outflows", detail_type: "Transportation")
  end

  test "derives a balanced journal entry from expense meaning" do
    expense = build_expense
    entry = expense.journal_entry_draft

    assert_equal 2, entry.journal_entry_lines.size
    assert_equal [ @fuel.id, 4_000_000, 0 ], line_signature(entry.journal_entry_lines.first)
    assert_equal [ @bank.id, 0, 4_000_000 ], line_signature(entry.journal_entry_lines.second)
    assert Accounting::Engine.check(entry.journal_entry_lines).ok?
  end

  test "supports split category lines" do
    uniforms = create_account(name: "Uniforms", base_type: "expense", account_type: "Personal Outflows", detail_type: "Living & Daily Needs")
    expense = build_expense
    expense.expense_lines.build(account: uniforms, description: "Uniform", amount_kobo: 1_000_000, position: 1)

    entry = expense.journal_entry_draft

    assert_equal 3, entry.journal_entry_lines.size
    assert_equal 5_000_000, expense.total_kobo
    assert_equal 5_000_000, entry.journal_entry_lines.last.credit_kobo
    assert_equal "Fuel and Uniform", expense.description
    assert_equal "Fuel and Uniforms", expense.category_label
  end

  test "rejects an ineligible payment account" do
    loan = create_account(name: "Loan", base_type: "liability", account_type: "Short-Term Debt", detail_type: "Short-Term Loans")
    expense = build_expense(payment_account: loan)

    assert_not expense.valid?
    assert_includes expense.errors[:payment_account], "must be an asset or credit-card account"
  end

  test "rejects an ineligible category account" do
    income = create_account(name: "Salary", base_type: "income", account_type: "Personal Inflows", detail_type: "Earned Salary & Wages")
    expense = build_expense(category: income)

    assert_not expense.valid?
    assert_includes expense.expense_lines.first.errors[:account], "is not an eligible expense category"
  end

  test "posts and links the expense atomically" do
    expense = build_expense
    expense.save!

    assert_difference("JournalEntry.count", 1) do
      assert_difference("JournalEntryLine.count", 2) do
        result = expense.post
        assert result.success?, result.errors.to_sentence
      end
    end

    assert expense.reload.posted?
    assert_equal expense.journal_entry.workspace, @workspace
    assert_equal 2, expense.journal_entry.journal_entry_lines.count
  end

  test "cannot be posted twice" do
    expense = build_expense
    expense.save!
    assert expense.post.success?

    assert_no_difference("JournalEntry.count") do
      result = expense.post
      assert_not result.success?
      assert_includes result.errors, "has already been posted"
    end
  end

  test "posted expense lines are immutable" do
    expense = build_expense
    expense.save!
    assert expense.post.success?
    line = expense.expense_lines.first

    assert_not line.update(description: "Changed")
    assert_equal "Fuel", line.reload.description
  end

  private
    def create_account(**attributes)
      @workspace.accounts.create!(attributes)
    end

    def build_expense(payment_account: @bank, category: @fuel)
      @workspace.expenses.build(
        payment_date: Date.current,
        payment_account: payment_account,
        expense_lines_attributes: [
          { account: category, description: "Fuel", amount_kobo: 4_000_000, position: 0 }
        ]
      )
    end

    def line_signature(line)
      [ line.account_id, line.debit_kobo, line.credit_kobo ]
    end
end

require "test_helper"

class TransactionTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    Category.seed_defaults_for(@workspace)
    @income_category = @workspace.categories.income.find_by(name: "Sales")
    @expense_category = @workspace.categories.expense.find_by(name: "Other")
  end

  test "valid with a positive amount" do
    transaction = @workspace.transactions.build(kind: :income, amount_kobo: 100, category: @income_category, occurred_on: Date.current)
    assert transaction.valid?
  end

  test "invalid with a zero amount" do
    transaction = @workspace.transactions.build(kind: :income, amount_kobo: 0, category: @income_category, occurred_on: Date.current)
    assert_not transaction.valid?
    assert_includes transaction.errors[:amount_kobo], "must be greater than 0"
  end

  test "invalid with a negative amount" do
    transaction = @workspace.transactions.build(kind: :income, amount_kobo: -100, category: @income_category, occurred_on: Date.current)
    assert_not transaction.valid?
    assert_includes transaction.errors[:amount_kobo], "must be greater than 0"
  end

  test "invalid when category kind does not match transaction kind" do
    transaction = @workspace.transactions.build(kind: :income, amount_kobo: 100, category: @expense_category, occurred_on: Date.current)
    assert_not transaction.valid?
    assert_includes transaction.errors[:category], "must match transaction kind"
  end

  test "invalid when customer is set on an expense" do
    customer = @workspace.customers.create!(name: "Chidi")
    transaction = @workspace.transactions.build(kind: :expense, amount_kobo: 100, category: @expense_category, occurred_on: Date.current, customer: customer)
    assert_not transaction.valid?
    assert_includes transaction.errors[:customer], "can only be set for income transactions"
  end

  test "invalid when category belongs to another workspace" do
    other_workspace = workspaces(:bola_shop)
    Category.seed_defaults_for(other_workspace)
    other_category = other_workspace.categories.income.find_by(name: "Sales")

    transaction = @workspace.transactions.build(kind: :income, amount_kobo: 100, category: other_category, occurred_on: Date.current)
    assert_not transaction.valid?
    assert_includes transaction.errors[:category], "must belong to the same workspace"
  end

  test "invalid when customer belongs to another workspace" do
    other_workspace = workspaces(:bola_shop)
    other_customer = other_workspace.customers.create!(name: "Zainab")

    transaction = @workspace.transactions.build(kind: :income, amount_kobo: 100, category: @income_category, occurred_on: Date.current, customer: other_customer)
    assert_not transaction.valid?
    assert_includes transaction.errors[:customer], "must belong to the same workspace"
  end

  test "amount= parses naira string into kobo" do
    transaction = @workspace.transactions.build(kind: :income, category: @income_category, occurred_on: Date.current)
    transaction.amount = "1500.50"
    assert_equal 150050, transaction.amount_kobo
  end

  test "amount returns kobo as naira BigDecimal" do
    transaction = @workspace.transactions.build(kind: :income, amount_kobo: 150050, category: @income_category, occurred_on: Date.current)
    assert_equal BigDecimal("1500.5"), transaction.amount
  end
end

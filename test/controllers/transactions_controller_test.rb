require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    Category.seed_defaults_for(@workspace)
    @category = @workspace.categories.income.find_by(name: "Sales")
    sign_in_as(@user)
  end

  test "creating a transaction updates it via turbo stream" do
    post transactions_path, params: {
      transaction: { kind: "income", amount: "150.00", category_id: @category.id, occurred_on: Date.current }
    }, as: :turbo_stream

    assert_response :success
    assert_equal 1, @workspace.transactions.count
  end

  test "creating an expense defaults correctly and reduces profit" do
    expense_category = @workspace.categories.expense.find_by(name: "Restock")

    post transactions_path, params: {
      transaction: { kind: "expense", amount: "75.00", category_id: expense_category.id, occurred_on: Date.current }
    }, as: :turbo_stream

    assert_response :success
    transaction = @workspace.transactions.last
    assert transaction.expense?
    assert_nil transaction.customer_id
    assert_equal 7500, transaction.amount_kobo
  end

  test "updating own transaction changes its amount" do
    transaction = @workspace.transactions.create!(kind: :income, amount_kobo: 1000, category: @category, occurred_on: Date.current)

    patch transaction_path(transaction), params: {
      transaction: { kind: "income", amount: "20.00", category_id: @category.id, occurred_on: Date.current }
    }, as: :turbo_stream

    assert_response :success
    assert_equal 2000, transaction.reload.amount_kobo
  end

  test "destroying own transaction removes it" do
    transaction = @workspace.transactions.create!(kind: :income, amount_kobo: 1000, category: @category, occurred_on: Date.current)

    assert_difference "Transaction.count", -1 do
      delete transaction_path(transaction), as: :turbo_stream
    end
    assert_response :success
  end

  test "cannot view another workspace's transaction" do
    other_workspace = workspaces(:bola_shop)
    Category.seed_defaults_for(other_workspace)
    other_category = other_workspace.categories.income.find_by(name: "Sales")
    other_transaction = other_workspace.transactions.create!(kind: :income, amount_kobo: 1000, category: other_category, occurred_on: Date.current)

    get edit_transaction_path(other_transaction)
    assert_response :not_found
  end

  test "cannot delete another workspace's transaction" do
    other_workspace = workspaces(:bola_shop)
    Category.seed_defaults_for(other_workspace)
    other_category = other_workspace.categories.income.find_by(name: "Sales")
    other_transaction = other_workspace.transactions.create!(kind: :income, amount_kobo: 1000, category: other_category, occurred_on: Date.current)

    assert_no_difference "Transaction.count" do
      delete transaction_path(other_transaction)
    end
    assert_response :not_found
  end
end

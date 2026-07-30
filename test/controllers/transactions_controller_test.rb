require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
  end

  test "creating a transaction updates it via turbo stream" do
    post transactions_path, params: {
      transaction: { kind: "income", amount: "150.00", category: "Sales", occurred_on: Date.current }
    }, as: :turbo_stream

    assert_response :success
    assert_equal 1, @workspace.transactions.count
  end

  test "creating an expense defaults correctly and reduces profit" do
    post transactions_path, params: {
      transaction: { kind: "expense", amount: "75.00", category: "Restock", occurred_on: Date.current }
    }, as: :turbo_stream

    assert_response :success
    transaction = @workspace.transactions.last
    assert transaction.expense?
    assert_nil transaction.customer_id
    assert_equal 7500, transaction.amount_kobo
  end

  test "updating own transaction changes its amount" do
    transaction = @workspace.transactions.create!(kind: :income, amount_kobo: 1000, category: "Sales", occurred_on: Date.current)

    patch transaction_path(transaction), params: {
      transaction: { kind: "income", amount: "20.00", category: "Sales", occurred_on: Date.current }
    }, as: :turbo_stream

    assert_response :success
    assert_equal 2000, transaction.reload.amount_kobo
  end

  test "destroying own transaction removes it" do
    transaction = @workspace.transactions.create!(kind: :income, amount_kobo: 1000, category: "Sales", occurred_on: Date.current)

    assert_difference "Transaction.count", -1 do
      delete transaction_path(transaction), as: :turbo_stream
    end
    assert_response :success
  end

  test "cannot view another workspace's transaction" do
    other_workspace = workspaces(:bola_shop)
    other_transaction = other_workspace.transactions.create!(kind: :income, amount_kobo: 1000, category: "Sales", occurred_on: Date.current)

    get edit_transaction_path(other_transaction)
    assert_response :not_found
  end

  test "cannot delete another workspace's transaction" do
    other_workspace = workspaces(:bola_shop)
    other_transaction = other_workspace.transactions.create!(kind: :income, amount_kobo: 1000, category: "Sales", occurred_on: Date.current)

    assert_no_difference "Transaction.count" do
      delete transaction_path(other_transaction)
    end
    assert_response :not_found
  end

  test "recording from a WhatsApp extraction stamps provenance and marks it recorded" do
    extraction = recordable_extraction

    assert_difference "@workspace.transactions.count", 1 do
      post transactions_path, params: {
        transaction: { kind: "expense", amount: "800.00", category: "Restock", occurred_on: Date.new(2026, 7, 4) },
        whatsapp_document_extraction_id: extraction.id
      }
    end

    assert_redirected_to document_reviews_path
    transaction = @workspace.transactions.last
    assert transaction.source_whatsapp?
    assert_equal extraction.whatsapp_message_id, transaction.whatsapp_message_id
    assert extraction.reload.review_recorded?
    assert_equal transaction.id, extraction.transaction_id
  end

  test "refuses to record the same extraction twice" do
    extraction = recordable_extraction
    extraction.update!(review_status: :recorded)

    assert_no_difference "Transaction.count" do
      post transactions_path, params: {
        transaction: { kind: "expense", amount: "800.00", category: "Restock", occurred_on: Date.new(2026, 7, 4) },
        whatsapp_document_extraction_id: extraction.id
      }
    end

    assert_redirected_to document_reviews_path
  end

  test "creating an entry posts it to the ledger with balanced postings" do
    post transactions_path, params: {
      transaction: { kind: "income", amount: "150.00", category: "Sales", occurred_on: Date.current }
    }, as: :turbo_stream

    transaction = @workspace.transactions.last
    assert_predicate transaction, :posted?
    assert_equal 2, transaction.postings.count
    assert_predicate transaction, :postings_balanced?
    assert_equal 150_00, LedgerSummary.new(@workspace).this_month.income_kobo
  end

  test "saving for later keeps the entry out of the ledger" do
    post transactions_path, params: {
      transaction: { kind: "expense", amount: "900.00", occurred_on: Date.current },
      draft: "1", return_to: "/transactions"
    }

    transaction = @workspace.transactions.last
    assert_predicate transaction, :draft?
    assert_empty transaction.postings
    assert_nil transaction.category
    assert_equal 0, LedgerSummary.new(@workspace).this_month.expense_kobo
    assert_equal 0, LedgerSummary.new(@workspace).balances.sum(&:amount_kobo)
  end

  test "adding a draft to the books posts it and fills what is missing" do
    Ledger::ChartOfAccounts.seed!(@workspace)
    draft = @workspace.transactions.create!(kind: :expense, amount_kobo: 900_00, occurred_on: Date.current, status: :draft)

    patch post_to_books_transaction_path(draft), headers: { "HTTP_REFERER" => transactions_url }

    assert_redirected_to transactions_url
    draft.reload
    assert_predicate draft, :posted?
    assert_predicate draft, :uncategorised?
    assert_equal "Cash", draft.account.name
    assert_equal 900_00, LedgerSummary.new(@workspace).this_month.expense_kobo
  end

  test "cannot post another workspace's draft to the books" do
    other_workspace = workspaces(:bola_shop)
    draft = other_workspace.transactions.create!(kind: :income, amount_kobo: 1000, occurred_on: Date.current, status: :draft)

    patch post_to_books_transaction_path(draft)

    assert_response :not_found
    assert_predicate draft.reload, :draft?
  end

  test "an entry with no amount is rejected rather than posted" do
    assert_no_difference "Transaction.count" do
      post transactions_path, params: {
        transaction: { kind: "income", amount: "", category: "Sales", occurred_on: Date.current }
      }
    end

    assert_response :unprocessable_entity
  end

  private
    def recordable_extraction
      message = @workspace.whatsapp_messages.create!(
        wamid: "wamid.rec.#{rand(1_000_000)}", message_type: "document", media_id: "m",
        sent_at: Time.current, classification_status: :classified
      )
      message.create_document_extraction!(
        document_type: :bank_transfer, currency: "NGN", currency_supported: true,
        amount_kobo: 80_000, direction_guess: :outward
      )
    end
end

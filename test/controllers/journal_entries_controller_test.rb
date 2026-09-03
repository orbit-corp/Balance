require "test_helper"

class JournalEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
  end

  test "searches journal entries by description" do
    cash = Account.for_role!(@workspace, :cash)
    income = Account.for_role!(@workspace, :uncategorized_income)
    matching_entry = post_journal_entry!(@workspace, debit_account: cash, credit_account: income, amount_kobo: 100_00, description: "Office lunch")
    hidden_entry = post_journal_entry!(@workspace, debit_account: cash, credit_account: income, amount_kobo: 200_00, description: "Opening balance")

    get journal_entries_path(q: "lunch")

    assert_response :success
    assert_select "tr##{dom_id(matching_entry)}"
    assert_select "tr##{dom_id(hidden_entry)}", count: 0
  end

  test "account selectors are searchable" do
    get new_journal_entry_path

    assert_response :success
    assert_select "[data-controller='select-menu'][data-select-menu-searchable-value='true']", count: 3
  end
end

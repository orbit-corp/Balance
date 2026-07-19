require "application_system_test_case"

class LoggingASaleTest < ApplicationSystemTestCase
  test "signing up and logging a sale" do
    visit new_registration_path

    fill_in "business_name", with: "Ngozi's Boutique"
    fill_in "email_address", with: "ngozi@example.com"
    fill_in "password", with: "supersecret123"
    click_on "Create account"

    assert_text "Log your first sale"

    click_on "Add sale", match: :first

    fill_in "Amount (₦)", with: "2500"
    click_on "Add entry"

    assert_text "Sales"
    assert_text "₦2,500.00"
  end

  test "logging an expense hides the customer field and defaults the category" do
    visit new_registration_path

    fill_in "business_name", with: "Femi's Electronics"
    fill_in "email_address", with: "femi@example.com"
    fill_in "password", with: "supersecret123"
    click_on "Create account"

    click_on "Add expense", match: :first

    assert_no_selector "[data-transaction-form-target='customerField']", visible: true
    assert_selector "select#transaction_category option[selected]", text: "Other"

    fill_in "Amount (₦)", with: "300"
    click_on "Add entry"

    assert_text "Expense"
    assert_text "₦300.00"
  end
end

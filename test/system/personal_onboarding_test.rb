require "application_system_test_case"

class PersonalOnboardingTest < ApplicationSystemTestCase
  test "signing up provisions a personal workspace" do
    visit new_registration_path

    fill_in "Full name", with: "Ngozi Okafor"
    fill_in "Email", with: "ngozi@example.com"
    fill_in "Password", with: "supersecret123"
    click_on "Create account"

    assert_text "What are you keeping track of?"
    assert_text "Business"
    assert_text "COMING SOON"
    click_on "Continue"

    fill_in "Workspace name", with: "Ngozi's Money"
    click_on "Continue"

    assert_text "Where do you keep or owe money?"
    assert_no_text "Opening Balance Equity"
    click_on "Create workspace"

    assert_text "Ngozi's Money"
    assert_text "Your personal workspace is ready."
  end

  test "business workspace is visibly unavailable" do
    visit new_registration_path

    fill_in "Full name", with: "Femi Adeyemi"
    fill_in "Email", with: "femi@example.com"
    fill_in "Password", with: "supersecret123"
    click_on "Create account"

    assert_text "Business"
    assert_text "COMING SOON"
    assert_no_field "workspace_type", with: "business"
  end
end

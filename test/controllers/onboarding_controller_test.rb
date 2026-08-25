require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(full_name: "Nneka Obi", email_address: "nneka@example.com", password: "supersecret123")
    sign_in_as(@user)
  end

  test "provisions a personal NGN workspace with core and selected accounts" do
    patch onboarding_step_path(:workspace_type), params: { workspace_type: "personal" }
    assert_redirected_to onboarding_step_path(:details)

    patch onboarding_step_path(:details), params: { workspace_name: "Nneka's Money" }
    assert_redirected_to onboarding_step_path(:accounts)

    assert_difference [ "Workspace.count", "Membership.count" ], 1 do
      assert_difference "Account.count", 7 do
        patch onboarding_step_path(:accounts), params: { starter_account_roles: %w[checking savings] }
      end
    end

    workspace = @user.workspaces.last
    assert_equal "personal", workspace.workspace_type
    assert_equal "NGN", workspace.currency_code
    assert workspace.onboarding_completed_at?
    assert_equal %w[cash checking opening_balance savings suspense uncategorized_expense uncategorized_income], workspace.accounts.order(:role).pluck(:role)
    assert_redirected_to dashboard_path
  end

  test "business selection remains unavailable" do
    assert_no_difference "Workspace.count" do
      patch onboarding_step_path(:workspace_type), params: { workspace_type: "business" }
    end

    assert_response :unprocessable_content
    assert_select "body", /coming soon/i
  end
end

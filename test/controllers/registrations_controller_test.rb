require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "signup creates an identity and starts onboarding" do
    assert_difference "User.count", 1 do
      assert_no_difference "Workspace.count" do
      post registration_path, params: {
        full_name: "Chidi Okafor",
        email_address: "chidi@example.com",
        password: "supersecret123"
      }
      end
    end

    assert_equal "Chidi Okafor", User.order(:created_at).last.full_name
    assert_redirected_to onboarding_step_path(:workspace_type)
    assert cookies[:session_id]
  end

  test "signup with invalid params re-renders the form" do
    assert_no_difference "User.count" do
      post registration_path, params: {
        full_name: "",
        email_address: "chidi@example.com",
        password: "supersecret123"
      }
    end

    assert_response :unprocessable_entity
  end
end

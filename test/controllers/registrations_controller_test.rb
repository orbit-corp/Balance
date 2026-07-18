require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "signup creates a workspace, seeds categories, and logs in" do
    assert_difference [ "Workspace.count", "User.count" ], 1 do
      post registration_path, params: {
        business_name: "Chidi's Fabrics",
        email_address: "chidi@example.com",
        password: "supersecret123"
      }
    end

    workspace = Workspace.order(:created_at).last
    assert_equal "Chidi's Fabrics", workspace.name
    assert_equal 2, workspace.categories.income.count
    assert_equal 7, workspace.categories.expense.count

    assert_redirected_to dashboard_path
    assert cookies[:session_id]
  end

  test "signup with invalid params re-renders the form" do
    assert_no_difference [ "Workspace.count", "User.count" ] do
      post registration_path, params: {
        business_name: "",
        email_address: "chidi@example.com",
        password: "supersecret123"
      }
    end

    assert_response :unprocessable_entity
  end
end

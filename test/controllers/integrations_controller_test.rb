require "test_helper"

class IntegrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
  end

  test "index lists integrations for the current workspace" do
    get integrations_path

    assert_response :success
    assert_select "h1", text: "Integrations"
  end
end

require "test_helper"

class Integrations::WhatsappControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
  end

  test "connect issues an active linking token for the current workspace" do
    assert_difference "@workspace.linking_tokens.count", 1 do
      post connect_integrations_whatsapp_path
    end

    assert_redirected_to integrations_path
    assert @workspace.linking_tokens.active.exists?
  end

  test "connect returns a wa.me deep link carrying the code as JSON" do
    post connect_integrations_whatsapp_path, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    token = @workspace.linking_tokens.active.last
    assert_includes body["deep_link"], "wa.me/"
    assert_includes body["deep_link"], token.token
  end

  test "disconnect removes the workspace's active link" do
    @workspace.whatsapp_links.create!(wa_id: "2348012349434", status: :active, linked_at: Time.current)

    assert_difference "@workspace.whatsapp_links.count", -1 do
      delete disconnect_integrations_whatsapp_path
    end

    assert_redirected_to integrations_path
  end
end

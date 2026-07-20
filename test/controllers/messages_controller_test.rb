require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @other_workspace = workspaces(:bola_shop)
    @user = users(:one)
    sign_in_as(@user)
  end

  test "index renders the messages page" do
    get messages_path

    assert_response :success
    assert_select "h1", text: "Messages"
  end

  test "index only shows the current workspace's messages" do
    mine = @workspace.whatsapp_messages.create!(wamid: "wamid.mine", message_type: "text", body: "Mine", sent_at: Time.current)
    @other_workspace.whatsapp_messages.create!(wamid: "wamid.other", message_type: "text", body: "NotMine", sent_at: Time.current)

    get messages_path

    assert_response :success
    assert_match "Mine", response.body
    assert_no_match "NotMine", response.body
  end
end

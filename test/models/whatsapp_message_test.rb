require "test_helper"

class WhatsappMessageTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
  end

  test "valid inbound text message" do
    message = @workspace.whatsapp_messages.build(
      wamid: "wamid.text.1",
      direction: :inbound,
      message_type: "text",
      body: "Hello",
      sent_at: Time.current
    )

    assert message.valid?
  end

  test "invalid without wamid" do
    message = @workspace.whatsapp_messages.build(message_type: "text")
    assert_not message.valid?
    assert_includes message.errors[:wamid], "can't be blank"
  end

  test "invalid without message_type" do
    message = @workspace.whatsapp_messages.build(wamid: "wamid.2")
    assert_not message.valid?
    assert_includes message.errors[:message_type], "can't be blank"
  end

  test "direction enum defaults to inbound" do
    message = @workspace.whatsapp_messages.create!(wamid: "wamid.3", message_type: "text", body: "Hi")
    assert message.inbound?
  end

  test "media_image? is true only for image type" do
    image_message = @workspace.whatsapp_messages.build(wamid: "wamid.4", message_type: "image")
    text_message = @workspace.whatsapp_messages.build(wamid: "wamid.5", message_type: "text")

    assert image_message.media_image?
    assert_not text_message.media_image?
  end

  test "chronological orders by sent_at then id" do
    older = @workspace.whatsapp_messages.create!(wamid: "wamid.6", message_type: "text", body: "a", sent_at: 2.hours.ago)
    newer = @workspace.whatsapp_messages.create!(wamid: "wamid.7", message_type: "text", body: "b", sent_at: 1.hour.ago)

    assert_equal [ older, newer ], @workspace.whatsapp_messages.chronological.to_a
  end
end

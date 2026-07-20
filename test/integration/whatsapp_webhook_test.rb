require "test_helper"

class WhatsappWebhookTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @other_workspace = workspaces(:bola_shop)
    @previous_app_secret = ENV["WHATSAPP_APP_SECRET"]
    ENV["WHATSAPP_APP_SECRET"] = ""
  end

  teardown do
    ENV["WHATSAPP_APP_SECRET"] = @previous_app_secret
  end

  test "a valid code creates an active link for the token's workspace" do
    token = LinkingToken.issue_for(@workspace)

    post webhooks_whatsapp_path, params: payload(token.token, wamid: "wamid.1", from: "2348012349434").to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :success
    link = @workspace.whatsapp_links.last
    assert link.present?
    assert link.active?
    assert link.linked_at.present?
    assert_equal "2348012349434", link.wa_id
    assert_not token.reload.active?
  end

  test "a duplicate wamid does not create a second link" do
    token = LinkingToken.issue_for(@workspace)
    body = payload(token.token, wamid: "wamid.dup", from: "2348012349434").to_json

    post webhooks_whatsapp_path, params: body, headers: { "Content-Type" => "application/json" }
    assert_response :success

    token2 = LinkingToken.issue_for(@workspace)
    body2 = payload(token2.token, wamid: "wamid.dup", from: "2348012349434").to_json
    post webhooks_whatsapp_path, params: body2, headers: { "Content-Type" => "application/json" }
    assert_response :success

    assert_equal 1, @workspace.whatsapp_links.where(wa_id: "2348012349434").count
  end

  test "a code already active on another workspace is rejected as a collision" do
    LinkingToken.issue_for(@workspace)
    @other_workspace.whatsapp_links.create!(wa_id: "2348012349434", status: :active, linked_at: Time.current)
    token = LinkingToken.issue_for(@workspace)

    post webhooks_whatsapp_path, params: payload(token.token, wamid: "wamid.collision", from: "2348012349434").to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :success
    assert_equal 0, @workspace.whatsapp_links.where(wa_id: "2348012349434").count
    assert token.reload.active?
  end

  test "an unknown code creates no link but still returns 200" do
    post webhooks_whatsapp_path, params: payload("LINK-ZZZZZZ", wamid: "wamid.unknown", from: "2348012349434").to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :success
    assert_equal 0, WhatsappLink.where(wa_id: "2348012349434").count
  end

  test "a text message from a linked sender is stored as an inbound message" do
    link = @workspace.whatsapp_links.create!(wa_id: "2348012349434", status: :active, linked_at: Time.current)

    post webhooks_whatsapp_path, params: text_payload("Here is my receipt", wamid: "wamid.text.1", from: "2348012349434").to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :success
    message = WhatsappMessage.find_by(wamid: "wamid.text.1")
    assert message.present?
    assert message.inbound?
    assert_equal @workspace.id, message.workspace_id
    assert_equal link.id, message.whatsapp_link_id
    assert_equal "text", message.message_type
    assert_equal "Here is my receipt", message.body
  end

  test "a linking code message is not stored as a WhatsappMessage" do
    token = LinkingToken.issue_for(@workspace)

    post webhooks_whatsapp_path, params: payload(token.token, wamid: "wamid.linkcode.1", from: "2348012349434").to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :success
    assert_nil WhatsappMessage.find_by(wamid: "wamid.linkcode.1")
  end

  test "a message from an unlinked sender is not stored" do
    post webhooks_whatsapp_path, params: text_payload("Hello there", wamid: "wamid.unlinked.1", from: "2348019999999").to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :success
    assert_nil WhatsappMessage.find_by(wamid: "wamid.unlinked.1")
  end

  test "an image message from a linked sender stores a message and enqueues the media download job" do
    @workspace.whatsapp_links.create!(wa_id: "2348012349434", status: :active, linked_at: Time.current)

    assert_enqueued_with(job: WhatsappMediaDownloadJob) do
      post webhooks_whatsapp_path, params: image_payload(media_id: "media.abc", wamid: "wamid.image.1", from: "2348012349434").to_json,
        headers: { "Content-Type" => "application/json" }
    end

    assert_response :success
    message = WhatsappMessage.find_by(wamid: "wamid.image.1")
    assert message.present?
    assert_equal "image", message.message_type
  end

  private
    def payload(code, wamid:, from:)
      {
        entry: [
          {
            changes: [
              {
                value: {
                  metadata: { phone_number_id: "123456" },
                  contacts: [ { profile: { name: "Test User" } } ],
                  messages: [
                    { id: wamid, from: from, type: "text", text: { body: code } }
                  ]
                }
              }
            ]
          }
        ]
      }
    end

    def text_payload(body, wamid:, from:)
      {
        entry: [
          {
            changes: [
              {
                value: {
                  metadata: { phone_number_id: "123456" },
                  contacts: [ { profile: { name: "Test User" } } ],
                  messages: [
                    { id: wamid, from: from, type: "text", timestamp: Time.current.to_i.to_s, text: { body: body } }
                  ]
                }
              }
            ]
          }
        ]
      }
    end

    def image_payload(media_id:, wamid:, from:)
      {
        entry: [
          {
            changes: [
              {
                value: {
                  metadata: { phone_number_id: "123456" },
                  contacts: [ { profile: { name: "Test User" } } ],
                  messages: [
                    { id: wamid, from: from, type: "image", timestamp: Time.current.to_i.to_s, image: { id: media_id, mime_type: "image/jpeg" } }
                  ]
                }
              }
            ]
          }
        ]
      }
    end
end

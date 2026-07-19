require "test_helper"

class WhatsappLinkTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
  end

  test "defaults to pending status" do
    link = @workspace.whatsapp_links.create!(wa_id: "2348012349434")
    assert link.pending?
  end

  test "approve! activates the link and sets linked_at" do
    link = @workspace.whatsapp_links.create!(wa_id: "2348012349434", status: :pending)

    link.approve!

    assert link.active?
    assert link.linked_at.present?
  end

  test "masked_wa_id shows only the last 4 digits" do
    link = @workspace.whatsapp_links.create!(wa_id: "2348012349434")
    assert_equal "…9434", link.masked_wa_id
  end

  test "invalid without wa_id" do
    link = @workspace.whatsapp_links.build(wa_id: nil)
    assert_not link.valid?
    assert_includes link.errors[:wa_id], "can't be blank"
  end
end

require "test_helper"

class RedirectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @campaign = @workspace.campaigns.create!(name: "Owambe")
  end

  test "sends a visitor to the destination and enqueues click capture" do
    shortlink = shortlink_for("https://example.com/wrappers", platform: :instagram)

    assert_enqueued_with(job: ClickRecorderJob) do
      get "/#{shortlink.slug}"
    end

    assert_response :found
    assert_match "https://example.com/wrappers", response.location
  end

  test "returns not found for an unknown slug" do
    get "/nope-not-here"

    assert_response :not_found
  end

  test "refuses to emit a destination with a non-http scheme" do
    shortlink = shortlink_for("https://example.com/ok", platform: :instagram)
    # Past the model validation — the controller is the last line of defence.
    shortlink.campaign_channel.update_column(:destination_url, "javascript:alert(1)")

    assert_no_enqueued_jobs(only: ClickRecorderJob) do
      get "/#{shortlink.slug}"
    end

    assert_response :not_found
  end

  # Sellers type a bare "wa.me/…"; stored as-is it is a relative path and the redirect raises.
  test "a destination typed without a scheme is made absolute and still redirects" do
    shortlink = shortlink_for("wa.me/2348012345678", platform: :whatsapp)

    assert_equal "https://wa.me/2348012345678", shortlink.campaign_channel.destination_url

    get "/#{shortlink.slug}"

    assert_response :found
    assert_match "https://wa.me/2348012345678", response.location
  end

  private
    def shortlink_for(destination_url, platform:)
      CampaignChannel.create_with_default_shortlink!(
        campaign: @campaign,
        platform: platform,
        destination_url: destination_url,
        host: "www.example.com"
      ).shortlinks.first
    end
end

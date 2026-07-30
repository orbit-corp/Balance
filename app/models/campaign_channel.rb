class CampaignChannel < ApplicationRecord
  belongs_to :campaign
  has_many :shortlinks, dependent: :destroy

  enum :platform, { whatsapp: 0, instagram: 1, facebook: 2, tiktok: 3, x: 4, sms: 5, other: 6 }

  before_validation :normalize_destination_url

  # Anchored at both ends and whitespace-free on purpose: a start-anchored pattern alone
  # would accept "https://ok.example\njavascript:..." and that string is later emitted as
  # a redirect target.
  validates :destination_url, presence: true,
            format: { with: %r{\A(?:https?://|wa\.me/)\S*\z}i, message: "must be a valid link" }

  def total_clicks
    Click.where(shortlink_id: shortlinks.select(:id)).count
  end

  # An additional variant on an already-created channel — never takes its own
  # destination_url, since variants share their channel's destination and the
  # seller edits it once for all of them (see data-model memory).
  def add_shortlink!(label:, host:)
    shortlinks.create!(host: host, label: label)
  end

  # A channel is never created bare — it always gets one default "main" variant
  # immediately, so the seller has a copyable link the moment the channel
  # exists without ever having to learn the word "variant" (see the create-flow
  # design in campaign-shortener-data-model memory).
  def self.create_with_default_shortlink!(campaign:, platform:, destination_url:, host:)
    channel = campaign.campaign_channels.create!(platform: platform, destination_url: destination_url)
    channel.shortlinks.create!(host: host, label: "main")
    channel
  end

  private
    # Sellers type "wa.me/234…" without a scheme. Stored bare, that string is a relative
    # path and the redirect raises, so it is made absolute here rather than at redirect
    # time. Anything that already declares a scheme is left alone for the format
    # validation to accept or reject.
    def normalize_destination_url
      return if destination_url.blank?

      self.destination_url = destination_url.strip
      return if destination_url.match?(%r{\A[a-z][a-z0-9+.\-]*:}i)

      self.destination_url = "https://#{destination_url}"
    end
end

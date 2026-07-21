class CampaignChannel < ApplicationRecord
  belongs_to :campaign
  has_many :shortlinks, dependent: :destroy

  enum :platform, { whatsapp: 0, instagram: 1, facebook: 2, tiktok: 3, x: 4, sms: 5, other: 6 }

  validates :destination_url, presence: true, format: { with: %r{\Ahttps?://|\Awa\.me/}i, message: "must be a valid link" }

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
end

class CampaignChannel < ApplicationRecord
  belongs_to :campaign
  has_many :shortlinks, dependent: :destroy

  enum :platform, { whatsapp: 0, instagram: 1, facebook: 2, tiktok: 3, x: 4, sms: 5, other: 6 }

  before_validation :normalize_destination_url

  validates :destination_url, presence: true,
            format: { with: %r{\A(?:https?://|wa\.me/)\S*\z}i, message: "must be a valid link" }

  def total_clicks
    Click.where(shortlink_id: shortlinks.select(:id)).count
  end

  def add_shortlink!(label:, host:)
    shortlinks.create!(host: host, label: label)
  end

  def self.create_with_default_shortlink!(campaign:, platform:, destination_url:, host:)
    channel = campaign.campaign_channels.create!(platform: platform, destination_url: destination_url)
    channel.shortlinks.create!(host: host, label: "main")
    channel
  end

  private
    def normalize_destination_url
      return if destination_url.blank?

      self.destination_url = destination_url.strip
      return if destination_url.match?(%r{\A[a-z][a-z0-9+.\-]*:}i)

      self.destination_url = "https://#{destination_url}"
    end
end

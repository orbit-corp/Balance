class Campaign < ApplicationRecord
  belongs_to :workspace
  has_many :campaign_channels, dependent: :destroy
  has_many :shortlinks, through: :campaign_channels
  # campaign_id is set on every Conversion recorded from this campaign's form,
  # whether attributed to a shortlink or not — see Conversion for why.
  has_many :conversions, -> { order(occurred_at: :desc) }, dependent: :nullify

  enum :status, { active: 0, archived: 1 }

  # Detected (from referrer) is the secondary breakdown axis, kept separate
  # from the declared CampaignChannel platform — see campaign-shortener
  # data-model memory ("they can disagree — reshares; keep named distinctly").
  DETECTED_CHANNEL_PATTERNS = {
    "Instagram" => /instagram\.com/i,
    "Facebook" => /facebook\.com|fb\.com/i,
    "TikTok" => /tiktok\.com/i,
    "X" => /twitter\.com|x\.com/i,
    "Google" => /google\./i,
    "WhatsApp" => /whatsapp\.com|wa\.me/i
  }.freeze

  validates :name, presence: true

  def clicks_scope
    Click.where(shortlink_id: shortlinks.select(:id))
  end

  def total_clicks
    clicks_scope.count
  end

  def human_clicks_count
    clicks_scope.where(bot: false).count
  end

  def bot_clicks_count
    clicks_scope.where(bot: true).count
  end

  def click_series(days: 30)
    Click.daily_series(clicks_scope, days: days)
  end

  # Declared channel = the platform the seller told us they're sharing on;
  # this is the primary dashboard axis (see data-model memory).
  def channel_click_counts
    campaign_channels.map { |channel| { channel: channel, count: Click.where(shortlink_id: channel.shortlinks.select(:id)).count } }
  end

  # Secondary axis: what the click's referrer actually says, when it says
  # anything. WhatsApp and SMS shares never carry a referrer at all, so this
  # is always a partial picture — never presented as if it were complete.
  def detected_channel_breakdown
    with_referrer = clicks_scope.where.not(referrer: [ nil, "" ])
    buckets = Hash.new(0)
    with_referrer.pluck(:referrer).each do |referrer|
      label = DETECTED_CHANNEL_PATTERNS.find { |_, pattern| referrer.match?(pattern) }&.first || "Other"
      buckets[label] += 1
    end
    buckets
  end

  def total_revenue_kobo
    conversions.sum(:amount_kobo)
  end

  # A forwarded WhatsApp message whose text carried one of this campaign's ref
  # tags — surfaced as a suggested (never forced) attribution candidate on the
  # "record a sale" form. See Whatsapp::MessageProcessor for the detection side.
  def recent_ref_match
    WhatsappMessage.where(matched_shortlink_id: shortlinks.select(:id)).order(sent_at: :desc).first
  end
end

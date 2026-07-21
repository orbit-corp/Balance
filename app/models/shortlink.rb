class Shortlink < ApplicationRecord
  # Kept distinct from WhatsappLink (the WA account connection) — this is the
  # user-facing "variant" link that redirects to a campaign channel's destination.
  belongs_to :campaign_channel
  has_many :clicks, dependent: :destroy
  has_many :conversions, dependent: :nullify

  enum :status, { active: 0, paused: 1 }

  # Small spike-scope reserved list: existing top-level route segments plus a
  # handful of obvious words. The full reserved-word policy is still to settle.
  RESERVED_SLUGS = %w[
    up session registration passwords dashboard integrations transactions
    customers messages document_reviews campaigns webhooks admin api login
    signup app about
  ].freeze

  SLUG_ALPHABET = ("a".."z").to_a + ("2".."9").to_a - %w[l o] # drop ambiguous chars

  before_validation :assign_host, on: :create
  before_validation :generate_slug, on: :create
  before_validation :generate_ref_code, on: :create

  validates :host, presence: true
  validates :slug, presence: true, uniqueness: { scope: :host },
                    format: { with: /\A[a-z0-9-]+\z/, message: "can only contain letters, numbers and dashes" },
                    length: { maximum: 30 },
                    exclusion: { in: RESERVED_SLUGS, message: "is reserved — try another" }
  validates :ref_code, presence: true, uniqueness: true

  # Below this, a sparkline is mostly noise — the design shows "too few to
  # chart" instead of a near-empty line.
  MIN_CLICKS_TO_CHART = 5

  def short_url
    "#{host}/#{slug}"
  end

  def click_series(days: 30)
    Click.daily_series(clicks, days: days)
  end

  def too_few_to_chart?
    clicks.count < MIN_CLICKS_TO_CHART
  end

  def destination_url
    campaign_channel.destination_url
  end

  def redirect_url
    campaign_channel.whatsapp? ? whatsapp_redirect_url : query_param_redirect_url
  end

  private
    # WhatsApp ignores unknown query params, so a plain ?ref= never survives the
    # jump. The seller's own wa.me link (with whatever text= they already set) is
    # never regenerated — we only insert the ref tag into its existing message.
    def whatsapp_redirect_url
      uri = URI.parse(destination_url)
      params = uri.query.present? ? URI.decode_www_form(uri.query) : []
      ref_tag = "(ref: #{ref_code})"

      if (text_param = params.find { |key, _| key == "text" })
        text_param[1] = "#{text_param[1]} #{ref_tag}".strip
      else
        params << [ "text", ref_tag ]
      end

      uri.query = URI.encode_www_form(params)
      uri.to_s
    rescue URI::InvalidURIError
      destination_url
    end

    def query_param_redirect_url
      uri = URI.parse(destination_url)
      separator = uri.query.present? ? "&" : "?"
      "#{destination_url}#{separator}ref=#{ref_code}"
    rescue URI::InvalidURIError
      destination_url
    end

    def assign_host
      self.host ||= ENV.fetch("SHORTLINK_HOST", "stby.co")
    end

    # Check-then-insert, same pattern as Dub's getRandomKey: generate a random
    # candidate, look it up, regenerate on a hit. The unique index on
    # (host, slug) is the actual correctness guarantee under a race — this
    # loop is just what keeps that race vanishingly unlikely to ever fire.
    def generate_slug
      return if slug.present?

      loop do
        candidate = Array.new(7) { SLUG_ALPHABET.sample }.join
        next if RESERVED_SLUGS.include?(candidate)
        break self.slug = candidate unless self.class.exists?(host: host, slug: candidate)
      end
    end

    def generate_ref_code
      self.ref_code ||= SecureRandom.alphanumeric(8).upcase
    end
end

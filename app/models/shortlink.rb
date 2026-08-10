class Shortlink < ApplicationRecord
  belongs_to :campaign_channel
  has_many :clicks, dependent: :destroy
  has_many :conversions, dependent: :nullify

  enum :status, { active: 0, paused: 1 }

  RESERVED_SLUGS = %w[
    up session registration passwords dashboard integrations transactions
    customers messages document_reviews campaigns webhooks admin api login
    signup app about
  ].freeze

  SLUG_ALPHABET = ("a".."z").to_a + ("2".."9").to_a - %w[l o]

  before_validation :assign_host, on: :create
  before_validation :generate_slug, on: :create
  before_validation :generate_ref_code, on: :create

  validates :host, presence: true
  validates :slug, presence: true, uniqueness: { scope: :host },
                    format: { with: /\A[a-z0-9-]+\z/, message: "can only contain letters, numbers and dashes" },
                    length: { maximum: 30 },
                    exclusion: { in: RESERVED_SLUGS, message: "is reserved — try another" }
  validates :ref_code, presence: true, uniqueness: true

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

class ShortLink < ApplicationRecord
  before_validation :normalize_long_url
  validates :long_url, presence: true
  validate :long_url_must_be_a_valid_url

  after_create :assign_short_code!

  private

  def normalize_long_url
    self.long_url = long_url.to_s.strip
  end

  def long_url_must_be_a_valid_url
    return if long_url.blank?

    uri = URI.parse(long_url)
    errors.add(:long_url, "must be a valid URL") unless uri.scheme.present? && uri.host.present?
  rescue URI::InvalidURIError
    errors.add(:long_url, "must be a valid URL")
  end

  def assign_short_code!
    update_column(:short_code, Base62.encode(id))
  end
end

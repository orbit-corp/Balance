class LinkingToken < ApplicationRecord
  belongs_to :workspace

  TTL = 10.minutes
  CODE_ALPHABET = "23456789ABCDEFGHJKMNPQRSTVWXYZ"
  CODE_LENGTH = 6

  scope :active, -> { where(consumed_at: nil).where("expires_at > ?", Time.current) }

  def self.issue_for(workspace)
    transaction do
      workspace.linking_tokens.active.update_all(consumed_at: Time.current)
      workspace.linking_tokens.create!(token: generate_token, expires_at: TTL.from_now)
    end
  end

  def consume!
    update!(consumed_at: Time.current)
  end

  def expired?
    expires_at <= Time.current
  end

  def active?
    consumed_at.nil? && !expired?
  end

  def self.generate_token
    "LINK-" + Array.new(CODE_LENGTH) { CODE_ALPHABET[SecureRandom.random_number(CODE_ALPHABET.length)] }.join
  end
  private_class_method :generate_token
end

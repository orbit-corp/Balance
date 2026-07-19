class WhatsappProcessedMessage < ApplicationRecord
  validates :wamid, presence: true

  def self.seen?(wamid)
    exists?(wamid: wamid)
  end

  def self.record!(wamid)
    create!(wamid: wamid)
  rescue ActiveRecord::RecordNotUnique
    false
  end
end

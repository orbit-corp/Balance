class WhatsappMessage < ApplicationRecord
  belongs_to :workspace
  belongs_to :whatsapp_link, optional: true
  has_one_attached :media

  enum :direction, { inbound: 0, outbound: 1 }
  enum :media_status, { pending: 0, downloaded: 1, failed: 2 }

  validates :wamid, presence: true
  validates :message_type, presence: true

  scope :chronological, -> { order(sent_at: :asc, id: :asc) }

  def media_image?
    message_type == "image"
  end
end

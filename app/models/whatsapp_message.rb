class WhatsappMessage < ApplicationRecord
  belongs_to :workspace
  belongs_to :whatsapp_link, optional: true
  has_one_attached :media
  has_one :document_extraction, class_name: "WhatsappDocumentExtraction", dependent: :destroy

  enum :direction, { inbound: 0, outbound: 1 }
  enum :media_status, { pending: 0, downloaded: 1, failed: 2 }
  # Names kept distinct from media_status so the generated predicates don't collide.
  enum :classification_status, { unclassified: 0, classified: 1, classification_failed: 2 }

  validates :wamid, presence: true
  validates :message_type, presence: true

  scope :chronological, -> { order(sent_at: :asc, id: :asc) }

  def media_image?
    message_type == "image"
  end

  # Attachments the vision layer knows how to read: image screenshots and documents
  # (the classifier inspects the downloaded content type to pick PDF vs image).
  def classifiable_media?
    media_image? || message_type == "document"
  end
end

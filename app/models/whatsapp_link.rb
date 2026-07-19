class WhatsappLink < ApplicationRecord
  belongs_to :workspace

  enum :status, { pending: 0, active: 1 }

  validates :wa_id, presence: true
  validates :status, presence: true

  def approve!
    update!(status: :active, linked_at: Time.current)
  end

  def masked_wa_id
    "…#{wa_id.to_s.last(4)}"
  end
end

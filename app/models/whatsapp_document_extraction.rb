class WhatsappDocumentExtraction < ApplicationRecord
  belongs_to :whatsapp_message
  belongs_to :recorded_journal_entry, class_name: "JournalEntry", foreign_key: :journal_entry_id, optional: true

  enum :document_type, { not_financial: 0, needs_review: 1, bank_transfer: 2 }
  enum :review_status, { pending: 0, recorded: 1, dismissed: 2 }, prefix: :review
  enum :direction_guess, { unknown: 0, outward: 1, inward: 2 }, prefix: :direction

  # Naira transfers we can act on: recognised as a transfer, in a supported currency,
  # not yet turned into a transaction or dismissed.
  scope :recordable, -> { bank_transfer.where(currency_supported: true).review_pending }

  # Everything worth surfacing in the review queue: transfers and low-confidence
  # "possibly financial" docs the user hasn't actioned yet.
  scope :awaiting_review, -> { review_pending.where(document_type: [ :bank_transfer, :needs_review ]) }

  def amount
    return nil if amount_kobo.nil?

    BigDecimal(amount_kobo) / 100
  end
end

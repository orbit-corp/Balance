class Proposal < ApplicationRecord
  TYPES = %w[journal_entry].freeze
  STATUSES = %w[proposed confirmed dismissed superseded].freeze

  belongs_to :workspace
  belongs_to :llm_chat, class_name: "Llm::Chat"
  belongs_to :llm_message, class_name: "Llm::Message", optional: true
  belongs_to :journal_entry, optional: true

  validates :proposal_type, presence: true, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :data, presence: true

  scope :proposed, -> { where(status: "proposed") }
  scope :by_type, ->(type) { where(proposal_type: type) }

  def journal_entry_proposal?
    proposal_type == "journal_entry"
  end

  def pending?
    status == "proposed"
  end

  def confirmed?
    status == "confirmed"
  end

  def description = data&.dig("description")
  def entry_date = data&.dig("entry_date")
  def shape = data&.dig("shape")
  def needs_attention = data&.dig("needs_attention")
  def lines = data&.dig("lines") || []

  def total_debit_kobo
    lines.sum { |line| line["side"] == "debit" ? line["amount_kobo"].to_i : 0 }
  end

  def total_credit_kobo
    lines.sum { |line| line["side"] == "credit" ? line["amount_kobo"].to_i : 0 }
  end

  # Slot presence is mechanical and checkable; which shape applies is the model's
  # judgment and is exactly what the user is confirming, so it is never checked here.
  def complete?
    return false if entry_date.blank?
    return false if lines.size < 2
    return false if lines.any? { |line| line["account_id"].blank? || line["amount_kobo"].to_i <= 0 }

    total_debit_kobo == total_credit_kobo
  end

  def confirm!(journal_entry:)
    update!(status: "confirmed", journal_entry: journal_entry)
  end

  def dismiss!
    update!(status: "dismissed")
  end

  def supersede!
    update!(status: "superseded")
  end
end

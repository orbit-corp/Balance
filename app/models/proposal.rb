class Proposal < ApplicationRecord
  TYPES = %w[journal_entry].freeze
  STATUSES = %w[proposed confirming confirmed dismissed superseded].freeze

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

  def complete?
    return false if entry_date.blank?
    return false if lines.size < 2
    return false if lines.any? { |line| line["account_id"].blank? || line["amount_kobo"].to_i <= 0 }

    total_debit_kobo == total_credit_kobo
  end

  def confirm!(draft:)
    with_lock do
      return [] unless pending?
      return draft.errors if draft.invalid?
      return [] unless transition_to_confirming?

      journal_entry = draft.build_journal_entry!
      update!(status: "confirmed", journal_entry: journal_entry)
      nil
    end
  end

  def dismiss!
    update!(status: "dismissed")
  end

  def supersede!
    update!(status: "superseded")
  end

  private

  def transition_to_confirming?
    Proposal.where(id: id, status: "proposed")
      .update_all(status: "confirming", updated_at: Time.current) == 1
  end
end

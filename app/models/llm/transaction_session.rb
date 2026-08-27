class Llm::TransactionSession < ApplicationRecord
  self.table_name = "llm_transaction_sessions"

  STATUSES = %w[open paused completed abandoned].freeze

  belongs_to :llm_chat, class_name: "Llm::Chat"
  belongs_to :last_question_message, class_name: "Llm::Message", optional: true
  has_many :llm_turns, class_name: "Llm::Turn", dependent: :nullify

  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: %w[open paused]) }

  def merge_facts!(new_facts)
    present_facts = new_facts.to_h.reject do |_key, value|
      value.nil? || value == ""
    end
    merged = facts.merge(present_facts)
    update!(facts: merged)
  end
end

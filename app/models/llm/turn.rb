class Llm::Turn < ApplicationRecord
  self.table_name = "llm_turns"

  STATUSES = %w[queued classifying responding working completed failed].freeze

  belongs_to :llm_chat, class_name: "Llm::Chat"
  belongs_to :user_message, class_name: "Llm::Message"
  belongs_to :llm_transaction_session, class_name: "Llm::TransactionSession", optional: true
  has_many :output_messages, class_name: "Llm::Message", foreign_key: :llm_turn_id, dependent: :nullify

  validates :status, inclusion: { in: STATUSES }
  validates :user_message_id, uniqueness: true

  scope :unfinished, -> { where.not(status: %w[completed failed]) }

  def finish!
    update!(status: "completed", completed_at: Time.current)
  end

  def fail!(message)
    update!(status: "failed", error: message, completed_at: Time.current)
  end
end

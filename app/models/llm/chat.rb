class Llm::Chat < ApplicationRecord
  belongs_to :workspace
  has_many :proposals, foreign_key: :llm_chat_id, dependent: :destroy

  acts_as_chat messages: :llm_messages, message_class: "Llm::Message", messages_foreign_key: :llm_chat_id, model: :llm_model, model_class: "Llm::Model"

  def timeline
    items = []
    visible_messages.each { |message| items << { type: :message, record: message, at: message.created_at } }
    proposals.each { |proposal| items << { type: :proposal, record: proposal, at: proposal.created_at } }
    items.sort_by { |item| item[:at] }
  end

  def visible_messages
    llm_messages.where(role: %w[user assistant]).where.not(content: [ nil, "" ]).order(:created_at, :id)
  end

  def latest_proposal(type = nil)
    scope = proposals.proposed
    scope = scope.by_type(type) if type
    scope.order(version: :desc).first
  end

  def derive_title_from(prompt)
    truncated = prompt.to_s.squish.delete_suffix(".").truncate(60, separator: " ", omission: "…")
    self.title = truncated.present? ? truncated[0].upcase + truncated[1..] : "New chat"
  end
end

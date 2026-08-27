class Llm::Activity < ApplicationRecord
  belongs_to :llm_chat, class_name: "Llm::Chat"

  validates :kind, :content, :turn_user_message_id, presence: true
end

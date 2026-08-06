class Llm::Chat < ApplicationRecord
  belongs_to :workspace

  acts_as_chat messages: :llm_messages, message_class: 'Llm::Message', messages_foreign_key: :llm_chat_id, model: :llm_model, model_class: 'Llm::Model'
end

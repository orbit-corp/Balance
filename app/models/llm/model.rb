class Llm::Model < ApplicationRecord
  self.table_name = "llm_models"

  acts_as_model chats: :llm_chats, chat_class: "Llm::Chat", chats_foreign_key: :llm_model_id
end

class Llm::Model < ApplicationRecord
  self.table_name = "llm_models"

  acts_as_model chats: :llm_chats, chat_class: "Llm::Chat", chats_foreign_key: :llm_model_id

  def self.resolve(model_id)
    RubyLLM.models.find(model_id.presence || RubyLLM.config.default_model)
  rescue RubyLLM::ModelNotFoundError
    refresh!
  end
end

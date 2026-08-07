class LlmChatResponseJob < ApplicationJob
  def perform(llm_chat_id)
    Llm::ChatTurn.new(chat: Llm::Chat.find(llm_chat_id)).call
  end
end

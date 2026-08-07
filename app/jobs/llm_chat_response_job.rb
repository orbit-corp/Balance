class LlmChatResponseJob < ApplicationJob
  def perform(llm_chat_id, content)
    Llm::ChatTurn.new(chat: Llm::Chat.find(llm_chat_id), content: content).call
  end
end

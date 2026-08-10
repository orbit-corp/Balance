class LlmChatTitleJob < ApplicationJob
  discard_on ActiveRecord::RecordNotFound

  def perform(llm_chat_id)
    llm_chat = Llm::Chat.find(llm_chat_id)

    title = Llm::TitleGenerator.new(llm_chat).call
    return if title.blank? || title == llm_chat.title

    llm_chat.update!(title: title)
    Llm::ChatBroadcaster.new(llm_chat).title(title)
  end
end

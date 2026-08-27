class LlmChatResponseJob < ApplicationJob
  limits_concurrency to: 1, key: ->(llm_chat_id, *) { llm_chat_id }, duration: 5.minutes

  def perform(llm_chat_id, llm_turn_id = nil)
    chat = Llm::Chat.find(llm_chat_id)
    turn = llm_turn_id ? chat.llm_turns.find(llm_turn_id) : chat.llm_turns.where(status: "queued").order(:id).first
    return unless turn

    Llm::ChatTurn.new(chat: chat, turn: turn).call
  rescue StandardError => error
    turn&.fail!("#{error.class}: #{error.message}") unless turn&.status.in?(%w[completed failed])
    Llm::ChatBroadcaster.new(chat, turn: turn).remove_turn_status if chat && turn
    raise
  end
end

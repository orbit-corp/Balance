class Llm::Message < ApplicationRecord
  acts_as_message chat: :llm_chat, chat_class: "Llm::Chat", tool_calls: :llm_tool_calls, tool_call_class: "Llm::ToolCall", tool_calls_foreign_key: :llm_message_id, model: :llm_model, model_class: "Llm::Model"

  after_create_commit :broadcast_append_if_visible
  after_update_commit :broadcast_replace_if_visible

  def broadcast_append_chunk(content)
    broadcast_append_to "llm_chat_#{llm_chat_id}",
      target: "llm_message_#{id}_content",
      content: ERB::Util.html_escape(content.to_s)
  end

  private

  def broadcast_append_if_visible
    return unless role == "assistant"

    broadcast_append_to "llm_chat_#{llm_chat_id}", target: "llm_messages"
  end

  def broadcast_replace_if_visible
    broadcast_replace_to "llm_chat_#{llm_chat_id}" if role == "assistant" && content.present?
  end
end

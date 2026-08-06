class Llm::Message < ApplicationRecord
  acts_as_message chat: :llm_chat, chat_class: 'Llm::Chat', tool_calls: :llm_tool_calls, tool_call_class: 'Llm::ToolCall', tool_calls_foreign_key: :llm_message_id, model: :llm_model, model_class: 'Llm::Model'

  broadcasts_to ->(llm_message) { "llm_chat_#{llm_message.llm_chat_id}" }, inserts_by: :append

  def broadcast_append_chunk(content)
    broadcast_append_to "llm_chat_#{llm_chat_id}",
      target: "llm_message_#{id}_content",
      content: ERB::Util.html_escape(content.to_s)
  end
end

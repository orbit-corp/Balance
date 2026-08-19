class Llm::ToolCall < ApplicationRecord
  acts_as_tool_call message: :llm_message, message_class: "Llm::Message", result_foreign_key: :llm_tool_call_id
end

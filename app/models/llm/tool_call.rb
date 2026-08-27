class Llm::ToolCall < ApplicationRecord
  self.table_name = "llm_tool_calls"

  acts_as_tool_call message: :llm_message, message_class: "Llm::Message", result_foreign_key: :llm_tool_call_id

  def display_output
    return symbolize_output(trace_output) if trace_output.present?

    message = Llm::Message.find_by(llm_tool_call_id: id)
    return if message&.content.blank?

    JSON.parse(message.content, symbolize_names: true)
  rescue JSON::ParserError
    message.content
  end

  def trace_failed?
    trace_status == "failed" || display_output.is_a?(Hash) && display_output[:error].present?
  end

  private

  def symbolize_output(value)
    case value
    when Array
      value.map { |item| symbolize_output(item) }
    when Hash
      value.deep_symbolize_keys
    else
      value
    end
  end
end

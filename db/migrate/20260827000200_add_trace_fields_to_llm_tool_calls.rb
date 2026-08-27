class AddTraceFieldsToLlmToolCalls < ActiveRecord::Migration[8.1]
  def change
    add_column :llm_tool_calls, :trace_status, :string
    add_column :llm_tool_calls, :trace_output, :jsonb, default: {}, null: false
  end
end

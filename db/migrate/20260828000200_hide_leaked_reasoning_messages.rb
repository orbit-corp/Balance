class HideLeakedReasoningMessages < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE llm_messages
      SET internal = TRUE
      WHERE role = 'assistant'
        AND thinking_text IS NOT NULL
        AND (
          content ILIKE '%missing_facts%'
          OR content ILIKE '%CURRENT TURN ROUTE%'
          OR content ILIKE '%<think>%'
          OR content ILIKE '%scratchpad%'
        )
    SQL
  end
end

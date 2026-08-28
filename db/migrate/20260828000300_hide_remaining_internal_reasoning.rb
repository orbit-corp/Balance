class HideRemainingInternalReasoning < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE llm_messages
      SET internal = TRUE
      WHERE role = 'assistant'
        AND (
          content ILIKE '%missing_facts%'
          OR content ILIKE '%CURRENT TURN ROUTE%'
          OR content ILIKE '%<think>%'
          OR content ILIKE '%scratchpad%'
          OR content ILIKE '%Let me step back and think about what might be happening%'
        )
    SQL
  end
end

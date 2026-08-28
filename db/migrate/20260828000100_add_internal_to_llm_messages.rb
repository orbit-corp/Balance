class AddInternalToLlmMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :llm_messages, :internal, :boolean, default: false, null: false
    add_index :llm_messages, [ :llm_chat_id, :internal ]
  end
end

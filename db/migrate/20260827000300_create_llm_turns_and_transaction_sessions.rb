class CreateLlmTurnsAndTransactionSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_turns do |t|
      t.references :llm_chat, null: false, foreign_key: true
      t.references :user_message, null: false, index: { unique: true }, foreign_key: { to_table: :llm_messages }
      t.string :status, null: false, default: "queued"
      t.text :error
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :llm_turns, [ :llm_chat_id, :status ]
    add_reference :llm_messages, :llm_turn, foreign_key: true
  end
end

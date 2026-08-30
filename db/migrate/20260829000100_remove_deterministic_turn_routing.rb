class RemoveDeterministicTurnRouting < ActiveRecord::Migration[8.0]
  def up
    remove_reference :llm_turns, :llm_transaction_session, foreign_key: true
    remove_columns :llm_turns, :intent, :relationship, :allowed_tools, :classification, :context_message_ids
    drop_table :llm_transaction_sessions
  end

  def down
    create_table :llm_transaction_sessions do |t|
      t.references :llm_chat, null: false, foreign_key: true
      t.string :status, null: false, default: "open"
      t.jsonb :facts, null: false, default: {}
      t.jsonb :source_message_ids, null: false, default: []
      t.references :last_question_message, foreign_key: { to_table: :llm_messages }
      t.timestamps
    end
    add_index :llm_transaction_sessions, [ :llm_chat_id, :status ]

    add_reference :llm_turns, :llm_transaction_session, foreign_key: true
    add_column :llm_turns, :intent, :string
    add_column :llm_turns, :relationship, :string
    add_column :llm_turns, :allowed_tools, :jsonb, null: false, default: []
    add_column :llm_turns, :classification, :jsonb, null: false, default: {}
    add_column :llm_turns, :context_message_ids, :jsonb, null: false, default: []
  end
end

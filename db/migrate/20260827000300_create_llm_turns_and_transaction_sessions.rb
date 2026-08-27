class CreateLlmTurnsAndTransactionSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_turns do |t|
      t.references :llm_chat, null: false, foreign_key: true
      t.references :user_message, null: false, index: { unique: true }, foreign_key: { to_table: :llm_messages }
      t.string :status, null: false, default: "queued"
      t.string :intent
      t.string :relationship
      t.jsonb :allowed_tools, null: false, default: []
      t.jsonb :classification, null: false, default: {}
      t.jsonb :context_message_ids, null: false, default: []
      t.text :error
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :llm_turns, [ :llm_chat_id, :status ]

    create_table :llm_transaction_sessions do |t|
      t.references :llm_chat, null: false, foreign_key: true
      t.string :status, null: false, default: "open"
      t.jsonb :facts, null: false, default: {}
      t.jsonb :source_message_ids, null: false, default: []
      t.bigint :last_question_message_id
      t.timestamps
    end

    add_index :llm_transaction_sessions, [ :llm_chat_id, :status ]
    add_foreign_key :llm_transaction_sessions, :llm_messages, column: :last_question_message_id
    add_reference :llm_turns, :llm_transaction_session, foreign_key: true
    add_reference :llm_messages, :llm_turn, foreign_key: true
  end
end

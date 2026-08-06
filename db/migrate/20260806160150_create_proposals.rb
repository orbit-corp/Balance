class CreateProposals < ActiveRecord::Migration[8.1]
  def change
    create_table :proposals do |t|
      t.references :workspace,     null: false, foreign_key: true
      t.references :llm_chat,      null: false, foreign_key: { to_table: :llm_chats }
      t.references :llm_message,   foreign_key: { to_table: :llm_messages }
      t.references :journal_entry, foreign_key: true
      t.string  :proposal_type, null: false
      t.string  :status,        null: false, default: "proposed"
      t.integer :version,       null: false, default: 1
      t.jsonb   :data,          null: false, default: {}
      t.timestamps
    end
    add_index :proposals, [ :workspace_id, :status ]
    add_index :proposals, [ :llm_chat_id, :proposal_type, :version ]
  end
end

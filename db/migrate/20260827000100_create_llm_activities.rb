class CreateLlmActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_activities do |t|
      t.references :llm_chat, null: false, foreign_key: true
      t.bigint :turn_user_message_id, null: false
      t.string :kind, null: false
      t.text :content, null: false

      t.timestamps
    end

    add_index :llm_activities,
      [ :llm_chat_id, :turn_user_message_id, :kind ],
      unique: true,
      name: "index_llm_activities_on_turn_and_kind"
  end
end

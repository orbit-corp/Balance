class CreateLlmChats < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_chats do |t|
      t.references :workspace, null: false, foreign_key: true
      t.timestamps
    end
  end
end

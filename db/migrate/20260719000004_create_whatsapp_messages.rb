class CreateWhatsappMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :whatsapp_messages do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :whatsapp_link, null: true, foreign_key: true
      t.string :wamid, null: false
      t.integer :direction, null: false, default: 0
      t.string :message_type, null: false
      t.text :body
      t.string :media_id
      t.datetime :sent_at

      t.timestamps
    end
    add_index :whatsapp_messages, :wamid, unique: true
    add_index :whatsapp_messages, [ :workspace_id, :sent_at ]
  end
end

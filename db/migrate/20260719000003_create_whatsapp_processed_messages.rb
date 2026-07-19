class CreateWhatsappProcessedMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :whatsapp_processed_messages do |t|
      t.string :wamid, null: false

      t.timestamps
    end
    add_index :whatsapp_processed_messages, :wamid, unique: true
  end
end

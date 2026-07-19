class CreateWhatsappLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :whatsapp_links do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :wa_id, null: false
      t.string :phone_number_id
      t.string :profile_name
      t.integer :status, null: false, default: 0
      t.datetime :requested_at
      t.datetime :linked_at
      t.datetime :last_message_at

      t.timestamps
    end
    add_index :whatsapp_links, :wa_id, unique: true, where: "status = 1", name: "idx_whatsapp_links_active_wa_id"
  end
end

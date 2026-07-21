class AddClassificationStatusToWhatsappMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :whatsapp_messages, :classification_status, :integer, null: false, default: 0
  end
end

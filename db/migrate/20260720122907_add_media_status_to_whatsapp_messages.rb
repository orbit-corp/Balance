class AddMediaStatusToWhatsappMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :whatsapp_messages, :media_status, :integer, null: false, default: 0
  end
end

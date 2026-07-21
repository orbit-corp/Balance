class AddMatchedShortlinkToWhatsappMessages < ActiveRecord::Migration[8.1]
  def change
    add_reference :whatsapp_messages, :matched_shortlink, foreign_key: { to_table: :shortlinks }
  end
end

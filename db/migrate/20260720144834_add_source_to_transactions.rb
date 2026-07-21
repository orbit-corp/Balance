class AddSourceToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :source, :integer, null: false, default: 0
    add_reference :transactions, :whatsapp_message, null: true, foreign_key: true
  end
end

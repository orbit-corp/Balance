class CreateWhatsappDocumentExtractions < ActiveRecord::Migration[8.1]
  def change
    create_table :whatsapp_document_extractions do |t|
      t.references :whatsapp_message, null: false, foreign_key: true, index: { unique: true }
      t.references :transaction, null: true, foreign_key: true

      t.integer :document_type, null: false, default: 0
      t.integer :review_status, null: false, default: 0
      t.integer :direction_guess, null: false, default: 0

      t.string :currency
      t.boolean :currency_supported, null: false, default: false
      t.integer :amount_kobo

      t.string :sender_name
      t.string :recipient_name
      t.string :recipient_bank
      t.string :reference_number
      t.date :transaction_date
      t.text :narration

      t.float :confidence
      t.text :raw_text

      t.timestamps
    end
  end
end

class CreatePostings < ActiveRecord::Migration[8.1]
  def change
    create_table :postings do |t|
      t.references :transaction, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      # Signed kobo: debits positive, credits negative. The postings of one
      # transaction always sum to zero — that invariant is the ledger.
      t.bigint :amount_kobo, null: false

      t.timestamps
    end
  end
end

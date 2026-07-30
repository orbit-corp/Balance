class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.integer :kind, null: false
      t.integer :amount_kobo, null: false
      # Nullable while a draft: a quick capture records how much and which way,
      # leaving the category and the money account to be supplied before posting.
      t.string :category
      t.references :account, foreign_key: true
      t.integer :status, null: false, default: 0
      t.references :customer, foreign_key: true
      t.date :occurred_on, null: false
      t.text :description

      t.timestamps
    end
    add_index :transactions, [ :workspace_id, :occurred_on ]
    add_index :transactions, [ :workspace_id, :kind ]
    add_index :transactions, [ :workspace_id, :status ]
  end
end

class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :payment_account, null: false, foreign_key: { to_table: :accounts }
      t.references :journal_entry, foreign_key: true, index: false
      t.date :payment_date, null: false
      t.string :status, null: false, default: "draft"

      t.timestamps
    end
    add_index :expenses, [ :workspace_id, :payment_date ]
    add_index :expenses, [ :workspace_id, :status ]
    add_index :expenses, :journal_entry_id, unique: true, where: "journal_entry_id IS NOT NULL"

    create_table :expense_lines do |t|
      t.references :expense, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.text :description, null: false
      t.bigint :amount_kobo, null: false
      t.integer :position, null: false

      t.timestamps
    end
    add_index :expense_lines, [ :expense_id, :position ], unique: true
  end
end

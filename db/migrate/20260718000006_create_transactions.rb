class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.integer :kind, null: false
      t.integer :amount_kobo, null: false
      t.string :category, null: false
      t.references :customer, foreign_key: true
      t.date :occurred_on, null: false
      t.text :description

      t.timestamps
    end
    add_index :transactions, [ :workspace_id, :occurred_on ]
    add_index :transactions, [ :workspace_id, :kind ]
  end
end

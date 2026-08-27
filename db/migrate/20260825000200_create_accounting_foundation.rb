class CreateAccountingFoundation < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :base_type, null: false
      t.string :account_type, null: false
      t.string :detail_type, null: false
      t.string :name, null: false
      t.string :role
      t.text :description

      t.timestamps
    end
    add_index :accounts, [ :workspace_id, :base_type ]
    add_index :accounts, [ :workspace_id, :account_type ]
    add_index :accounts, [ :workspace_id, :name ], unique: true
    add_index :accounts, [ :workspace_id, :role ], unique: true, where: "role IS NOT NULL"

    create_table :customers do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :phone

      t.timestamps
    end

    create_table :journal_entries do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :reverses_journal_entry, foreign_key: { to_table: :journal_entries }
      t.date :entry_date, null: false
      t.text :description, null: false

      t.timestamps
    end
    add_index :journal_entries, [ :workspace_id, :entry_date ]

    create_table :journal_entry_lines do |t|
      t.references :journal_entry, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.bigint :debit_kobo, null: false, default: 0
      t.bigint :credit_kobo, null: false, default: 0
      t.references :counterparty, polymorphic: true

      t.timestamps
    end
  end
end

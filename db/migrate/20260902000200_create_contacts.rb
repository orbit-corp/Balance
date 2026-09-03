class CreateContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :contacts do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :contact_kind, null: false
      t.string :email
      t.string :phone
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :contacts, [ :workspace_id, :name ]
    add_index :contacts, [ :workspace_id, :active ]

    create_table :contact_roles do |t|
      t.references :contact, null: false, foreign_key: true
      t.string :role, null: false

      t.timestamps
    end
    add_index :contact_roles, [ :contact_id, :role ], unique: true

    add_reference :expenses, :payee_contact, foreign_key: { to_table: :contacts }
    add_index :expenses,
      [ :workspace_id, :payee_contact_id, :payment_date, :total_kobo ],
      name: "index_expenses_for_transaction_duplicate_detection"
  end
end

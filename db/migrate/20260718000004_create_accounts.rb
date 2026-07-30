class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.references :workspace, null: false, foreign_key: true
      t.integer :kind, null: false
      t.string :name, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :accounts, [ :workspace_id, :kind ]
    add_index :accounts, [ :workspace_id, :kind, :name ], unique: true
  end
end

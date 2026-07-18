class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.references :workspace, null: false, foreign_key: true
      t.integer :kind, null: false
      t.string :name, null: false

      t.timestamps
    end
    add_index :categories, [ :workspace_id, :kind ]
  end
end

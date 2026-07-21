class CreateConversions < ActiveRecord::Migration[8.1]
  def change
    create_table :conversions do |t|
      t.references :workspace, null: false, foreign_key: true
      # Nullable — a nil shortlink is the first-class "unattributed" bucket, not
      # an edge case. Attribution status is derived from this, never a separate
      # column, so the two can't drift out of sync.
      t.references :shortlink, foreign_key: true
      t.integer :amount_kobo, null: false
      t.integer :kind, null: false, default: 1
      t.integer :confirmation_status, null: false, default: 0
      t.integer :source, null: false, default: 0
      t.datetime :occurred_at, null: false

      t.timestamps
    end
    add_index :conversions, [ :workspace_id, :created_at ]
  end
end

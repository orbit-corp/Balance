class CreateClicks < ActiveRecord::Migration[8.1]
  def change
    create_table :clicks do |t|
      t.references :shortlink, null: false, foreign_key: true
      t.string :ref_code, null: false
      t.datetime :occurred_at, null: false
      t.string :ip_address
      t.string :user_agent
      t.string :referrer
      t.boolean :bot, null: false, default: false

      t.timestamps
    end
    add_index :clicks, [ :shortlink_id, :occurred_at ]
  end
end

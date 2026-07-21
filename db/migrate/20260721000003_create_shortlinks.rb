class CreateShortlinks < ActiveRecord::Migration[8.1]
  def change
    create_table :shortlinks do |t|
      t.references :campaign_channel, null: false, foreign_key: true
      t.string :host, null: false
      t.string :slug, null: false
      t.string :ref_code, null: false
      t.string :label
      t.integer :status, null: false, default: 0

      t.timestamps
    end
    add_index :shortlinks, [ :host, :slug ], unique: true
    add_index :shortlinks, :ref_code, unique: true
  end
end

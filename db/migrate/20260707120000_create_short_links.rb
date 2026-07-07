class CreateShortLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :short_links do |t|
      t.string :short_code
      t.text :long_url, null: false

      t.timestamps
    end

    add_index :short_links, :short_code, unique: true
  end
end

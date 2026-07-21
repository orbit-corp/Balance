class CreateCampaignChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :campaign_channels do |t|
      t.references :campaign, null: false, foreign_key: true
      t.integer :platform, null: false
      t.string :destination_url, null: false

      t.timestamps
    end
    add_index :campaign_channels, [ :campaign_id, :platform ]
  end
end

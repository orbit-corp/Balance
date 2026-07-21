class AddCampaignToConversions < ActiveRecord::Migration[8.1]
  def change
    # Attribution (shortlink_id) can be nil — that's the honest "unattributed"
    # bucket. But the conversion was still recorded from a specific campaign's
    # form, and without capturing that, an unattributed sale becomes invisible
    # on the very page that created it. campaign_id is the scoping fix.
    add_reference :conversions, :campaign, foreign_key: true
  end
end

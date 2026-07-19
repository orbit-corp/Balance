class CreateLinkingTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :linking_tokens do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at

      t.timestamps
    end
    add_index :linking_tokens, :token, unique: true
  end
end

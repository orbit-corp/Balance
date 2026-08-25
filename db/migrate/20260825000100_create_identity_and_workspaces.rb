class CreateIdentityAndWorkspaces < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :full_name, null: false
      t.string :email_address, null: false
      t.string :password_digest, null: false

      t.timestamps
    end
    add_index :users, :email_address, unique: true

    create_table :workspaces do |t|
      t.string :name, null: false
      t.string :workspace_type, null: false, default: "personal"
      t.string :currency_code, null: false, default: "NGN"
      t.datetime :onboarding_completed_at

      t.timestamps
    end

    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :workspace, null: false, foreign_key: true
      t.string :role, null: false, default: "owner"

      t.timestamps
    end
    add_index :memberships, [ :user_id, :workspace_id ], unique: true

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :workspace, foreign_key: true
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
  end
end

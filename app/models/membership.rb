class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :workspace

  enum :role, { owner: "owner" }, validate: true

  validates :user_id, uniqueness: { scope: :workspace_id }
end

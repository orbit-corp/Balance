class Session < ApplicationRecord
  belongs_to :user
  belongs_to :workspace, optional: true

  validate :workspace_is_accessible_to_user

  private

  def workspace_is_accessible_to_user
    return if workspace.blank? || user.blank?
    return if user.workspaces.exists?(workspace.id)

    errors.add(:workspace, "must be accessible to the user")
  end
end

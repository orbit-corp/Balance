require "test_helper"

class Workspaces::ProvisionerTest < ActiveSupport::TestCase
  test "creates the owner membership and valid double-entry account classes" do
    user = User.create!(full_name: "Ife Bello", email_address: "ife@example.com", password: "supersecret123")

    workspace = Workspaces::Provisioner.call(
      user: user,
      name: "Ife's Finances",
      workspace_type: "personal",
      currency_code: "NGN"
    )

    assert_equal user, workspace.memberships.owner.first.user
    assert_equal %w[asset equity expense income liability], workspace.accounts.distinct.order(:base_type).pluck(:base_type)
    assert_equal "asset", workspace.accounts.find_by!(role: "cash").base_type
    assert_equal "Opening Balance", workspace.accounts.find_by!(role: "opening_balance").detail_type
    assert_equal AccountCatalogs::Personal.core.keys.sort,
                 workspace.accounts.pluck(:role).map(&:to_sym).sort
  end

  test "does not provision business workspaces before they are supported" do
    user = User.create!(full_name: "Ife Bello", email_address: "ife@example.com", password: "supersecret123")

    assert_raises(ArgumentError) do
      Workspaces::Provisioner.call(
        user: user,
        name: "Ife Limited",
        workspace_type: "business",
        currency_code: "NGN"
      )
    end
  end
end

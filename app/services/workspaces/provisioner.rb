module Workspaces
  class Provisioner
    def self.call(...)
      new(...).call
    end

    def initialize(user:, name:, workspace_type:, currency_code:, starter_account_roles:)
      @user = user
      @name = name
      @workspace_type = workspace_type
      @currency_code = currency_code
      @starter_account_roles = starter_account_roles.map(&:to_sym)
    end

    def call
      raise ArgumentError, "Business workspaces are coming soon" unless @workspace_type == "personal"

      Workspace.transaction do
        workspace = Workspace.create!(
          name: @name,
          workspace_type: @workspace_type,
          currency_code: @currency_code,
          onboarding_completed_at: Time.current
        )
        workspace.memberships.create!(user: @user, role: :owner)
        workspace.seed_core_accounts!
        @starter_account_roles.each { |role| Account.for_role!(workspace, role) }
        workspace
      end
    end
  end
end

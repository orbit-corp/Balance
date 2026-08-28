module Workspaces
  class Provisioner
    def self.call(...)
      new(...).call
    end

    def initialize(user:, name:, workspace_type:, currency_code:, opening_balance_kobo: 0)
      @user = user
      @name = name
      @workspace_type = workspace_type
      @currency_code = currency_code
      @opening_balance_kobo = opening_balance_kobo
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
        post_opening_balance!(workspace) if @opening_balance_kobo.positive?
        workspace
      end
    end

    private

    def post_opening_balance!(workspace)
      entry = workspace.journal_entries.build(
        description: "Opening balance",
        entry_date: Date.current,
        journal_entry_lines_attributes: [
          { account: Account.for_role!(workspace, :checking), debit_kobo: @opening_balance_kobo, credit_kobo: 0 },
          { account: Account.for_role!(workspace, :opening_balance), debit_kobo: 0, credit_kobo: @opening_balance_kobo }
        ]
      )

      result = Accounting::PostingService.call(entry: entry)
      raise ActiveRecord::RecordInvalid, entry unless result.success?
    end
  end
end

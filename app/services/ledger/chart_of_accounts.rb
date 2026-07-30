module Ledger
  # Seeds and resolves a workspace's chart of accounts. The income and expense
  # accounts are the categories the app already shows, so nothing new appears in
  # front of the seller — only the money accounts are a genuinely new idea.
  class ChartOfAccounts
    # Distinct from "Other": Other means the seller decided it was other,
    # Uncategorised means nobody has said yet. Keeping them apart is what lets us
    # prompt a tidy-up later.
    UNCATEGORISED = "Uncategorised".freeze

    # Deliberately generic and renameable — a seller names their own bank.
    MONEY_ACCOUNTS = [ "Cash", "Bank" ].freeze

    class << self
      def seed!(workspace)
        MONEY_ACCOUNTS.each_with_index do |name, index|
          find_or_create(workspace, :asset, name, index)
        end

        ApplicationHelper::TRANSACTION_CATEGORIES.each do |kind, categories|
          (categories + [ UNCATEGORISED ]).each_with_index do |name, index|
            find_or_create(workspace, kind, name, index)
          end
        end
      end

      def money_accounts(workspace)
        workspace.accounts.asset.ordered
      end

      def default_money_account(workspace)
        money_accounts(workspace).first || find_or_create(workspace, :asset, MONEY_ACCOUNTS.first, 0)
      end

      # The income or expense account a category posts against. Created on demand so
      # a category added to the app later never leaves a transaction unpostable.
      def category_account(workspace, kind, category)
        find_or_create(workspace, kind, category.presence || UNCATEGORISED, 99)
      end

      private
        def find_or_create(workspace, kind, name, position)
          workspace.accounts.create_with(position: position).find_or_create_by!(kind: kind, name: name)
        end
    end
  end
end

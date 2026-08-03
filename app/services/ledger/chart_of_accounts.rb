module Ledger
  class ChartOfAccounts
    UNCATEGORISED = "Uncategorised".freeze

    MONEY_ACCOUNTS = [ "Cash", "Bank" ].freeze

    class << self
      def seed!(workspace)
        MONEY_ACCOUNTS.each do |name|
          find_or_create(workspace, "asset", "bank", name)
        end

        ApplicationHelper::TRANSACTION_CATEGORIES.each do |kind, categories|
          account_type, account_subtype = type_for_kind(kind)

          (categories + [ UNCATEGORISED ]).each do |name|
            find_or_create(workspace, account_type, account_subtype, name)
          end
        end
      end

      def money_accounts(workspace)
        workspace.accounts.asset.ordered
      end

      def default_money_account(workspace)
        money_accounts(workspace).first || find_or_create(workspace, "asset", "bank", MONEY_ACCOUNTS.first)
      end

      def category_account(workspace, kind, category)
        account_type, account_subtype = type_for_kind(kind)
        find_or_create(workspace, account_type, account_subtype, category.presence || UNCATEGORISED)
      end

      private
        def type_for_kind(kind)
          kind.to_s == "income" ? [ "income", "sales" ] : [ "expenses", "general" ]
        end

        def find_or_create(workspace, account_type, account_subtype, name)
          workspace.accounts.find_or_create_by!(account_type: account_type, account_subtype: account_subtype, name: name)
        end
    end
  end
end

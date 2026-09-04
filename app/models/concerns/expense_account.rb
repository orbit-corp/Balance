module ExpenseAccount
  extend ActiveSupport::Concern

  PAYMENT_ACCOUNT_TYPES = [ "Bank", "Cash & Liquid Assets", "Credit Card" ].freeze
  PAYMENT_DETAIL_TYPES = [ "Credit Cards" ].freeze

  included do
    has_many :paid_expenses,
      class_name: "Expense",
      foreign_key: :payment_account_id,
      dependent: :restrict_with_error
    has_many :expense_lines, dependent: :restrict_with_error

    scope :expense_payment_accounts, -> {
      where(account_type: PAYMENT_ACCOUNT_TYPES)
        .or(where(detail_type: PAYMENT_DETAIL_TYPES))
    }
    scope :expense_category_accounts, -> { where(base_type: "expense") }
  end

  def expense_payment_account?
    account_type.in?(PAYMENT_ACCOUNT_TYPES) || detail_type.in?(PAYMENT_DETAIL_TYPES)
  end

  def expense_category_account?
    base_type == "expense"
  end
end

class Account < ApplicationRecord
  belongs_to :workspace
  has_many :journal_entry_lines, dependent: :restrict_with_error

  TAXONOMY = {
    "asset" => {
      "bank"                    => %w[checking savings cash_on_hand],
      "accounts_receivable"     => %w[accounts_receivable],
      "other_current_asset"     => %w[prepaid_expense loans_to_others other_current_asset]
    },
    "liability" => {
      "accounts_payable"        => %w[accounts_payable],
      "other_current_liability" => %w[loan_payable other_current_liability]
    },
    "equity" => {
      "equity"                  => %w[opening_balance]
    },
    "income" => {
      "income"                  => %w[other_primary_income],
      "other_income"            => %w[interest_earned other_income]
    },
    "expense" => {
      "expense"                 => %w[auto bank_charges charitable_contributions insurance
                                      rent_or_lease_of_buildings supplies utilities
                                      other_miscellaneous_expense]
    }
  }.freeze

  CREDIT_NORMAL_BASE_TYPES = %w[liability equity income].freeze

  CORE = {
    cash:            { name: "Cash",                   base: "asset",     type: "bank",                    detail: "cash_on_hand" },
    receivable:      { name: "Accounts Receivable",    base: "asset",     type: "accounts_receivable",     detail: "accounts_receivable" },
    payable:         { name: "Accounts Payable",       base: "liability", type: "accounts_payable",        detail: "accounts_payable" },
    suspense:        { name: "Suspense",               base: "liability", type: "other_current_liability", detail: "other_current_liability" },
    opening_balance: { name: "Opening Balance Equity", base: "equity",    type: "equity",                  detail: "opening_balance" },
    other_income:    { name: "Other Income",           base: "income",    type: "other_income",            detail: "other_income" },
    other_expense:   { name: "Other Expense",          base: "expense",   type: "expense",                 detail: "other_miscellaneous_expense" },
    bank_charges:    { name: "Bank Charges",           base: "expense",   type: "expense",                 detail: "bank_charges" }
  }.freeze

  SEED_ON_CREATE = CORE.keys.freeze

  validates :name, presence: true, uniqueness: { scope: :workspace_id }
  validates :base_type, inclusion: { in: TAXONOMY.keys }
  validates :account_type, presence: true
  validates :detail_type, presence: true
  validate :account_type_belongs_to_base_type
  validate :detail_type_belongs_to_account_type

  before_destroy { throw(:abort) if role.present? }
  before_update { throw(:abort) if role.present? && (base_type_changed? || account_type_changed?) }

  scope :ordered, -> { order(:name) }

  def self.for_role!(workspace, role)
    spec = CORE.fetch(role)
    workspace.accounts.find_or_create_by!(role: role) do |a|
      a.name        = spec[:name]
      a.base_type   = spec[:base]
      a.account_type = spec[:type]
      a.detail_type = spec[:detail]
    end
  end

  def normal_balance
    CREDIT_NORMAL_BASE_TYPES.include?(base_type) ? :credit : :debit
  end

  private

  def account_type_belongs_to_base_type
    return if base_type.blank? || account_type.blank?
    return if TAXONOMY.fetch(base_type, {}).key?(account_type)

    errors.add(:account_type, "is not valid for #{base_type}")
  end

  def detail_type_belongs_to_account_type
    return if base_type.blank? || account_type.blank? || detail_type.blank?
    return if TAXONOMY.dig(base_type, account_type)&.include?(detail_type)

    errors.add(:detail_type, "is not valid for #{account_type}")
  end
end

class Account < ApplicationRecord
  belongs_to :workspace
  has_many :journal_entry_lines, dependent: :restrict_with_error

  TAXONOMY = {
    "asset" => {
      "bank"                    => %w[checking savings cash_on_hand money_market],
      "accounts_receivable"     => %w[accounts_receivable],
      "other_current_asset"     => %w[inventory prepaid_expense undeposited_funds
                                      employee_cash_advances loans_to_others other_current_asset],
      "fixed_asset"             => %w[machinery_equipment vehicles furniture_fixtures buildings land
                                      leasehold_improvements accumulated_depreciation],
      "other_asset"             => %w[security_deposits goodwill licenses other_asset]
    },
    "liability" => {
      "credit_card"             => %w[credit_card],
      "accounts_payable"        => %w[accounts_payable],
      "other_current_liability" => %w[sales_tax_payable payroll_liabilities income_tax_payable
                                      deferred_revenue loan_payable line_of_credit
                                      other_current_liability],
      "long_term_liability"     => %w[notes_payable shareholder_notes_payable other_long_term_liability]
    },
    "equity" => {
      "equity"                  => %w[owner_capital owner_draw opening_balance]
    },
    "income" => {
      "income"                  => %w[sales_of_product_income service_fee_income
                                      discounts_refunds_given other_primary_income],
      "other_income"            => %w[interest_earned exchange_gain gain_on_disposal other_income]
    },
    "expense" => {
      "cost_of_goods_sold"      => %w[supplies_materials_cogs cost_of_labour_cogs
                                      shipping_freight_cogs other_costs_of_sales],
      "expense"                 => %w[advertising_promotional auto bad_debts bank_charges
                                      charitable_contributions dues_subscriptions insurance
                                      legal_professional_fees office_general_administrative
                                      payroll_expenses rent_or_lease_of_buildings repair_maintenance
                                      shipping_delivery supplies taxes_paid travel utilities
                                      depreciation other_miscellaneous_expense uncategorised_expense],
      "other_expense"           => %w[exchange_gain_or_loss amortization interest_paid
                                      penalties_settlements loss_on_disposal other_expense]
    }
  }.freeze

  CREDIT_NORMAL_BASE_TYPES = %w[liability equity income].freeze

  CORE = {
    cash:              { name: "Cash",                   base: "asset",     type: "bank",                    detail: "cash_on_hand" },
    receivable:        { name: "Accounts Receivable",    base: "asset",     type: "accounts_receivable",     detail: "accounts_receivable" },
    payable:           { name: "Accounts Payable",       base: "liability", type: "accounts_payable",        detail: "accounts_payable" },
    suspense:          { name: "Suspense",               base: "liability", type: "other_current_liability", detail: "other_current_liability" },
    owner_capital:     { name: "Owner's Equity",         base: "equity",    type: "equity",                  detail: "owner_capital" },
    owner_draw:        { name: "Owner's Drawings",       base: "equity",    type: "equity",                  detail: "owner_draw" },
    opening_balance:   { name: "Opening Balance Equity", base: "equity",    type: "equity",                  detail: "opening_balance" },
    sales:             { name: "Sales",                  base: "income",    type: "income",                  detail: "sales_of_product_income" },
    cogs:              { name: "Cost of Goods Sold",     base: "expense",   type: "cost_of_goods_sold",      detail: "other_costs_of_sales" },
    bank_charges:      { name: "Bank Charges",           base: "expense",   type: "expense",                 detail: "bank_charges" },
    uncategorised_exp: { name: "Uncategorised Expense",  base: "expense",   type: "expense",                 detail: "uncategorised_expense" }
  }.freeze

  SEED_ON_CREATE = %i[cash sales uncategorised_exp owner_capital].freeze

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

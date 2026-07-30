class Transaction < ApplicationRecord
  belongs_to :workspace
  belongs_to :customer, optional: true
  belongs_to :whatsapp_message, optional: true
  # The money account the entry moved through — required once posted, blank while
  # a draft is still being captured.
  belongs_to :account, optional: true
  has_many :postings, dependent: :destroy, inverse_of: :recorded_transaction

  enum :kind, { income: 0, expense: 1 }
  enum :status, { draft: 0, posted: 1, discarded: 2 }
  enum :source, { manual: 0, whatsapp: 1 }, prefix: :source

  scope :posted, -> { where(status: :posted) }
  scope :drafts, -> { where(status: :draft) }

  validates :amount_kobo, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :kind, presence: true
  validates :occurred_on, presence: true

  # A draft deliberately carries almost no validation — how much and which way is
  # all a quick capture needs. These only bind once the entry reaches the ledger.
  with_options if: :posted? do
    validates :category, presence: true, inclusion: { in: ->(transaction) { transaction.allowed_categories } }
    validates :account, presence: true
  end

  validate :customer_belongs_to_same_workspace
  validate :customer_only_present_for_income
  validate :account_belongs_to_same_workspace
  validate :account_holds_money

  def amount
    return nil if amount_kobo.nil?

    BigDecimal(amount_kobo) / 100
  end

  def amount=(value)
    self.amount_kobo = value.blank? ? nil : (BigDecimal(value.to_s) * 100).round
  end

  def allowed_categories
    ApplicationHelper::TRANSACTION_CATEGORIES.fetch(kind, []) + [ Ledger::ChartOfAccounts::UNCATEGORISED ]
  end

  def uncategorised?
    category == Ledger::ChartOfAccounts::UNCATEGORISED
  end

  def postings_balanced?
    postings.sum(&:amount_kobo).zero?
  end

  private
    def customer_belongs_to_same_workspace
      return if customer.nil? || workspace.nil?

      errors.add(:customer, "must belong to the same workspace") unless customer.workspace_id == workspace_id
    end

    def customer_only_present_for_income
      return if customer.nil?

      errors.add(:customer, "can only be set for income transactions") unless income?
    end

    def account_belongs_to_same_workspace
      return if account.nil? || workspace.nil?

      errors.add(:account, "must belong to the same workspace") unless account.workspace_id == workspace_id
    end

    def account_holds_money
      return if account.nil?

      errors.add(:account, "must be a money account") unless account.asset?
    end
end

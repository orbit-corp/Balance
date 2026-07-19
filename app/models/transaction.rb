class Transaction < ApplicationRecord
  belongs_to :workspace
  belongs_to :customer, optional: true

  enum :kind, { income: 0, expense: 1 }

  validates :amount_kobo, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :kind, presence: true
  validates :occurred_on, presence: true
  validates :category, presence: true, inclusion: { in: ->(transaction) { ApplicationHelper::TRANSACTION_CATEGORIES.fetch(transaction.kind, []) } }

  validate :customer_belongs_to_same_workspace
  validate :customer_only_present_for_income

  def amount
    return nil if amount_kobo.nil?

    BigDecimal(amount_kobo) / 100
  end

  def amount=(value)
    self.amount_kobo = value.blank? ? nil : (BigDecimal(value.to_s) * 100).round
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
end

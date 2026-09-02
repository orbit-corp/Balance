class Expense < ApplicationRecord
  belongs_to :workspace
  belongs_to :payment_account, class_name: "Account"
  belongs_to :journal_entry, optional: true
  has_many :expense_lines, -> { order(:position) }, dependent: :destroy, inverse_of: :expense

  accepts_nested_attributes_for :expense_lines, allow_destroy: true, reject_if: :all_blank

  enum :status, { draft: "draft", posted: "posted" }, validate: true

  validates :payment_date, presence: true
  validate :payment_date_is_not_in_the_future
  validate :payment_account_belongs_to_workspace
  validate :payment_account_is_eligible
  validate :has_category_lines

  before_update { throw(:abort) if status_in_database == "posted" }
  before_destroy { throw(:abort) if posted? }

  def total_kobo
    expense_lines.reject(&:marked_for_destruction?).sum(&:amount_kobo)
  end

  def category_label
    lines = expense_lines.reject(&:marked_for_destruction?)
    lines.one? ? lines.first.account.name : "Split (#{lines.size})"
  end

  def description
    lines = expense_lines.reject(&:marked_for_destruction?)
    lines.one? ? lines.first.description : "Split expense"
  end

  def journal_entry_draft
    workspace.journal_entries.build(
      entry_date: payment_date,
      description: description,
      journal_entry_lines_attributes: expense_lines.map do |line|
        { account: line.account, debit_kobo: line.amount_kobo, credit_kobo: 0 }
      end.push(account: payment_account, debit_kobo: 0, credit_kobo: total_kobo)
    )
  end

  def post
    Accounting::PostingService.call(entry: journal_entry_draft, source: self)
  end

  def record_posting!(entry)
    update!(journal_entry: entry, status: :posted)
  end

  private
    def payment_date_is_not_in_the_future
      return if payment_date.blank? || payment_date <= Date.current

      errors.add(:payment_date, "cannot be in the future")
    end

    def payment_account_belongs_to_workspace
      return if payment_account.blank? || workspace.blank?
      return if payment_account.workspace_id == workspace_id

      errors.add(:payment_account, "must belong to the workspace")
    end

    def payment_account_is_eligible
      return if payment_account.blank? || payment_account.expense_payment_account?

      errors.add(:payment_account, "must be a bank, cash, or credit-card account")
    end

    def has_category_lines
      return if expense_lines.reject(&:marked_for_destruction?).any?

      errors.add(:expense_lines, "must include at least one category")
    end
end

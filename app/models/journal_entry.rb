class JournalEntry < ApplicationRecord
  belongs_to :workspace
  has_many :journal_entry_lines, dependent: :destroy

  accepts_nested_attributes_for :journal_entry_lines, allow_destroy: true, reject_if: :all_blank

  validates :entry_date, presence: true
  validate :has_at_least_two_lines
  validate :lines_balance

  private

  def has_at_least_two_lines
    errors.add(:journal_entry_lines, "must contain at least two lines") unless journal_entry_lines.size >= 2
  end

  def lines_balance
    return if journal_entry_lines.sum(&:debit_kobo) == journal_entry_lines.sum(&:credit_kobo)

    errors.add(:base, "debits and credits must balance")
  end
end

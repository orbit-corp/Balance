class JournalEntry < ApplicationRecord
  belongs_to :workspace
  belongs_to :reverses_journal_entry, class_name: "JournalEntry", optional: true
  has_many :journal_entry_lines, dependent: :destroy, inverse_of: :journal_entry

  accepts_nested_attributes_for :journal_entry_lines, allow_destroy: true, reject_if: :all_blank

  validates :description, presence: true
  validates :entry_date, presence: true
  validate :has_at_least_two_lines
  validate :lines_balance
  validate :cannot_reverse_a_reversal
  validate :reversal_stays_in_workspace
  validate :entry_date_not_in_the_future
  validate :entry_date_not_too_far_in_the_past
  validate :same_account_not_on_both_sides
  validate :no_duplicate_lines

  before_update { throw(:abort) }
  before_destroy { throw(:abort) }

  def reverse!
    self.class.transaction do
      reversal = workspace.journal_entries.create!(
        entry_date: Date.current,
        description: "Reversal of journal entry #{id}",
        reverses_journal_entry: self,
        journal_entry_lines_attributes: journal_entry_lines.map do |line|
          {
            account_id: line.account_id,
            debit: line.credit,
            credit: line.debit,
            counterparty: line.counterparty
          }
        end
      )
      reversal
    end
  end

  private

  def cannot_reverse_a_reversal
    return if reverses_journal_entry.blank? || reverses_journal_entry.reverses_journal_entry_id.blank?

    errors.add(:reverses_journal_entry, "cannot reverse an entry that is itself a reversal")
  end

  def reversal_stays_in_workspace
    return if reverses_journal_entry.blank? || workspace.blank?
    return if reverses_journal_entry.workspace_id == workspace_id

    errors.add(:reverses_journal_entry, "must belong to the same workspace as the entry")
  end

  def has_at_least_two_lines
    errors.add(:journal_entry_lines, "must contain at least two lines") unless journal_entry_lines.size >= 2
  end

  def lines_balance
    total_debit = journal_entry_lines.sum { |line| line.debit_kobo.to_i }
    total_credit = journal_entry_lines.sum { |line| line.credit_kobo.to_i }

    errors.add(:base, "debits and credits must balance") unless total_debit == total_credit
  end

  def entry_date_not_in_the_future
    return if entry_date.blank?

    errors.add(:entry_date, "cannot be in the future") if entry_date > Date.current
  end

  def entry_date_not_too_far_in_the_past
    return if entry_date.blank?

    errors.add(:entry_date, "is too far in the past") if entry_date < 10.years.ago.to_date
  end

  def same_account_not_on_both_sides
    journal_entry_lines.group_by(&:account_id).each_value do |lines|
      next if lines.size < 2

      sides = lines.map { |line| line.debit_kobo.to_i.positive? ? "debit" : "credit" }.uniq
      errors.add(:base, "the same account cannot be both debited and credited") if sides.size > 1
    end
  end

  def no_duplicate_lines
    signatures = journal_entry_lines.map { |line| [ line.account_id, line.debit_kobo, line.credit_kobo ] }
    errors.add(:base, "duplicate journal lines are not allowed") if signatures.uniq.size < signatures.size
  end
end

class JournalEntry < ApplicationRecord
  belongs_to :workspace
  belongs_to :reverses_journal_entry, class_name: "JournalEntry", optional: true
  has_many :journal_entry_lines, dependent: :destroy, inverse_of: :journal_entry

  accepts_nested_attributes_for :journal_entry_lines, allow_destroy: true, reject_if: :all_blank

  validates :description, presence: true
  validates :entry_date, presence: true
  validate :complies_with_accounting_principles
  validate :cannot_reverse_a_reversal
  validate :reversal_stays_in_workspace
  validate :entry_date_not_in_the_future
  validate :entry_date_not_too_far_in_the_past

  before_update { throw(:abort) }
  before_destroy { throw(:abort) }

  def reverse!
    self.class.transaction do
      reversal = workspace.journal_entries.build(
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
      result = Accounting::PostingService.call(entry: reversal)
      raise ActiveRecord::RecordInvalid, reversal unless result.success?

      result.entry
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

  def complies_with_accounting_principles
    result = Accounting::Engine.check(journal_entry_lines)
    result.errors.each { |message| errors.add(:base, message) }
  end

  def entry_date_not_in_the_future
    return if entry_date.blank?

    errors.add(:entry_date, "cannot be in the future") if entry_date > Date.current
  end

  def entry_date_not_too_far_in_the_past
    return if entry_date.blank?

    errors.add(:entry_date, "is too far in the past") if entry_date < 10.years.ago.to_date
  end
end

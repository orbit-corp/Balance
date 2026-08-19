class LedgerIntegrityCheckJob < ApplicationJob
  def perform
    JournalEntry.find_each do |entry|
      next if entry.journal_entry_lines.size >= 2 &&
        entry.journal_entry_lines.sum(&:debit_kobo) == entry.journal_entry_lines.sum(&:credit_kobo)

      Rails.logger.error("Unbalanced journal entry detected: #{entry.id}")
      raise "Unbalanced journal entry detected: #{entry.id}"
    end
  end
end

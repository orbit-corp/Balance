class JournalEntryLine < ApplicationRecord
  belongs_to :journal_entry
  belongs_to :account

  validates :debit_kobo, :credit_kobo, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :exactly_one_side_is_positive

  def debit
    return nil if debit_kobo.nil?

    BigDecimal(debit_kobo) / 100
  end

  def debit=(value)
    self.debit_kobo = value.blank? ? 0 : (BigDecimal(value.to_s) * 100).round
  end

  def credit
    return nil if credit_kobo.nil?

    BigDecimal(credit_kobo) / 100
  end

  def credit=(value)
    self.credit_kobo = value.blank? ? 0 : (BigDecimal(value.to_s) * 100).round
  end

  private

  def exactly_one_side_is_positive
    return if debit_kobo.nil? || credit_kobo.nil?
    return if debit_kobo.positive? ^ credit_kobo.positive?

    errors.add(:base, "must have either a debit or a credit, not both or neither")
  end
end

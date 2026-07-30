# One side of a posted transaction. Debits are positive kobo, credits negative,
# and the postings of a transaction always sum to zero — that invariant is what
# makes the ledger the source of truth. Postings exist only once a transaction is
# posted, so a draft cannot reach any balance or total.
class Posting < ApplicationRecord
  belongs_to :recorded_transaction, class_name: "Transaction", foreign_key: :transaction_id, inverse_of: :postings
  belongs_to :account

  validates :amount_kobo, presence: true, numericality: { only_integer: true, other_than: 0 }

  scope :debits, -> { where(arel_table[:amount_kobo].gt(0)) }
  scope :credits, -> { where(arel_table[:amount_kobo].lt(0)) }
end

# A line in the workspace's chart of accounts. Asset accounts are the places
# money actually sits (Cash, a bank, a wallet); income and expense accounts are
# the categories a sale or expense lands against.
class Account < ApplicationRecord
  belongs_to :workspace
  has_many :postings, dependent: :restrict_with_error
  has_many :transactions, dependent: :restrict_with_error

  enum :kind, { asset: 0, income: 1, expense: 2 }

  validates :name, presence: true, uniqueness: { scope: %i[workspace_id kind] }
  validates :kind, presence: true

  scope :ordered, -> { order(:position, :name) }

  def balance_kobo
    postings.joins(:recorded_transaction).where(transactions: { status: Transaction.statuses[:posted] }).sum(:amount_kobo)
  end
end

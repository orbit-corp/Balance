class Account < ApplicationRecord
  belongs_to :workspace
  has_many :journal_entry_lines, dependent: :restrict_with_error

  TYPES = {
    "asset" => {
      "bank" => %w[cash_on_hand],
    },
    "liability" => {},
    "equity" => {},
    "income" => {
      "income" => %w[sales],
    },
    "expense" => {
      "expenses" => %w[general],
    },
  }.freeze

  validates :name, presence: true, uniqueness: { scope: %i[workspace_id account_type account_subtype] }

  scope :of_base_type, ->(base) { where(account_type: TYPES.fetch(base).keys) }
  scope :asset, -> { of_base_type("asset") }
  scope :income, -> { of_base_type("income") }
  scope :expense, -> { of_base_type("expense") }
  scope :ordered, -> { order(:name) }

  def base_type
    TYPES.find { |_base, account_types| account_types.key?(account_type) }&.first
  end
end

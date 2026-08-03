class Account < ApplicationRecord
  belongs_to :workspace

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
  validate :account_subtype_belongs_to_account_type

  scope :of_base_type, ->(base) { where(account_type: TYPES.fetch(base).keys) }
  scope :asset, -> { of_base_type("asset") }
  scope :income, -> { of_base_type("income") }
  scope :expense, -> { of_base_type("expense") }
  scope :ordered, -> { order(:name) }


  def base_type
    TYPES.find { |_base, account_types| account_types.key?(account_type) }&.first
  end

  private

  def account_subtype_belongs_to_account_type
    valid_subtypes = TYPES.values.flat_map(&:to_a).to_h[account_type]

    if valid_subtypes.nil?
      errors.add(:account_type, "is not a recognized account type")
    elsif account_subtype.present? && !valid_subtypes.include?(account_subtype)
      errors.add(:account_subtype, "is not valid for account_type #{account_type}")
    end
  end
end

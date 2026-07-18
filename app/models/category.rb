class Category < ApplicationRecord
  DEFAULTS = {
    income: %w[Sales Other],
    expense: [ "Restock", "Transport", "Data/Airtime", "Rent", "Utilities", "Fees", "Other" ]
  }.freeze

  belongs_to :workspace
  has_many :transactions

  enum :kind, { income: 0, expense: 1 }

  validates :name, presence: true
  validates :kind, presence: true
  validates :name, uniqueness: { scope: [ :workspace_id, :kind ] }

  def self.seed_defaults_for(workspace)
    DEFAULTS.each do |kind, names|
      names.each { |name| workspace.categories.create!(kind: kind, name: name) }
    end
  end
end

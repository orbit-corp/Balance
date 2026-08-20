class Account < ApplicationRecord
  belongs_to :workspace
  has_many :journal_entry_lines, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :workspace_id }
  validates :base_type, :account_type, :detail_type, presence: true

  scope :ordered, -> { order(:name) }

  private

  def catalog
    workspace.catalog
  end

  def catalog_category(base_type)
    catalog.chart_of_accounts.find { |category| category[:category].downcase == base_type }
  end

  def self.for_role!(workspace, role)
    spec = workspace.catalog.core.fetch(role)
    workspace.accounts.find_or_create_by!(role: role) do |a|
      a.name        = spec[:name]
      a.base_type   = spec[:base]
      a.account_type = spec[:type]
    end
  end
end

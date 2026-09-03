class Workspace < ApplicationRecord
  enum :workspace_type, { personal: "personal", business: "business" }, validate: true

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :journal_entries, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :accounts, dependent: :destroy
  has_many :llm_chats, class_name: "Llm::Chat", dependent: :destroy
  has_many :proposals, dependent: :destroy

  validates :name, presence: true
  validates :currency_code, inclusion: { in: %w[NGN] }

  def catalog
    AccountCatalog.for(workspace_type)
  end

  def seed_core_accounts!
    catalog.core.each_key { |role| Account.for_role!(self, role) }
  end
end

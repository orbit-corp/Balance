class Workspace < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :transactions, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :linking_tokens, dependent: :destroy
  has_many :whatsapp_links, dependent: :destroy

  validates :name, presence: true

  def whatsapp_link
    whatsapp_links.order(created_at: :desc).first
  end
end

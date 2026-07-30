class Workspace < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :transactions, dependent: :destroy
  has_many :accounts, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :campaigns, dependent: :destroy
  has_many :conversions, dependent: :destroy
  has_many :linking_tokens, dependent: :destroy
  has_many :whatsapp_links, dependent: :destroy
  has_many :whatsapp_messages, dependent: :destroy
  has_many :whatsapp_document_extractions, through: :whatsapp_messages, source: :document_extraction

  validates :name, presence: true

  def whatsapp_link
    whatsapp_links.order(created_at: :desc).first
  end
end

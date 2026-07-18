class Customer < ApplicationRecord
  belongs_to :workspace
  has_many :transactions

  validates :name, presence: true
end

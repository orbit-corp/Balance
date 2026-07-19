class Workspace < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :transactions, dependent: :destroy
  has_many :customers, dependent: :destroy

  validates :name, presence: true
end

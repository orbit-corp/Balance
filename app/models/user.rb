class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :workspaces, through: :memberships

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :full_name, presence: true
  validates :email_address, presence: true, uniqueness: true
end

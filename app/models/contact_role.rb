class ContactRole < ApplicationRecord
  belongs_to :contact

  enum :role, Contact::ROLE_NAMES.index_with(&:itself), validate: true

  validates :role, uniqueness: { scope: :contact_id }
end

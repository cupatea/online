class Category < ApplicationRecord
  belongs_to :profile
  # Deleting a category leaves its links in place, just uncategorized.
  has_many :links, dependent: :nullify

  validates :name, presence: true,
                   uniqueness: { scope: :profile_id, case_sensitive: false }

  scope :ordered, -> { order(:position, :id) }
end

class Profile < ApplicationRecord
  # Slugs that would shadow a real route (or a static file) — a profile can't
  # take one of these names, otherwise /:slug could never reach it anyway.
  RESERVED = %w[
    new up services service setting settings republish dashboard
    assets links edit rails default-bg icon
  ].freeze

  has_many :links, -> { ordered }, dependent: :destroy

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, presence: true,
                   uniqueness: true,
                   format: { with: /\A[a-z0-9-]+\z/, message: "must be letters, numbers, and dashes" },
                   exclusion: { in: RESERVED, message: "is reserved" }

  before_validation :set_slug

  scope :ordered, -> { order(:name) }

  def to_param = slug

  private

  def set_slug
    self.slug = name.to_s.parameterize.presence
  end
end

class Link < ApplicationRecord
  belongs_to :profile

  validates :title, presence: true
  validates :url,   presence: true

  before_validation :normalize_url

  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { order(:position, :id) }

  private

  # Let the user type "github.com" and treat it as an https:// URL.
  def normalize_url
    self.url = url.to_s.strip.presence
    return if url.nil? || url.match?(%r{\A[a-z][a-z0-9+.-]*://}i)

    self.url = "https://#{url}"
  end
end

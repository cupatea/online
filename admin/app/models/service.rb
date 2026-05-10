class Service < ApplicationRecord
  validates :name,          presence: true
  validates :hostname,      presence: true,
                            uniqueness: { case_sensitive: false },
                            format: { with: /\A[a-z0-9.-]+\z/i, message: "must be a valid hostname" }
  validates :upstream_host, presence: true
  validates :upstream_port, presence: true,
                            numericality: { only_integer: true, in: 1..65535 }

  before_validation :normalize_hostname

  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { order(:hostname) }

  def upstream
    "#{upstream_host}:#{upstream_port}"
  end

  private

  def normalize_hostname
    self.hostname = hostname.to_s.strip.downcase.presence
  end
end

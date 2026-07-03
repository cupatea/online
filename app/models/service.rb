class Service < ApplicationRecord
  # Virtual fields used by the form. The hostname is composed from a subdomain
  # prefix plus a base domain (e.g. "caramba" + "bulka.in" => caramba.bulka.in).
  # A blank subdomain maps the apex (the whole base domain).
  attr_accessor :subdomain, :base_domain

  # Dashboard grouping: "general" links (music, video, media…) render above
  # "technical" ones (monitoring, NAS…).
  CATEGORIES = %w[general technical].freeze

  validates :category, inclusion: { in: CATEGORIES }
  validates :name,          presence: true
  validates :hostname,      presence: true,
                            uniqueness: { case_sensitive: false },
                            format: { with: /\A[a-z0-9.*-]+\z/i, message: "must be a valid hostname" }
  validates :upstream_host, presence: true
  validates :upstream_port, presence: true,
                            numericality: { only_integer: true, in: 1..65535 }

  before_validation :compose_hostname
  before_validation :normalize_hostname
  before_validation :backfill_name

  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { order(:hostname) }

  def upstream
    "#{upstream_host}:#{upstream_port}"
  end

  # Splits the stored hostname back into subdomain + base_domain for the edit
  # form, using the known base domains to resolve where the boundary is
  # (so "caramba.bulka.in" with base "bulka.in" => sub "caramba", and the apex
  # "bulka.in" => empty subdomain). Falls back to "first label is the subdomain"
  # for hostnames that match no known base.
  def assign_host_parts(base_domains = [])
    return if hostname.blank?

    base = base_domains.find { |b| hostname == b || hostname.end_with?(".#{b}") }
    if base
      self.base_domain = base
      self.subdomain   = hostname == base ? "" : hostname.delete_suffix(".#{base}")
    elsif hostname.count(".") >= 2
      labels         = hostname.split(".")
      self.subdomain = labels.first
      self.base_domain = labels[1..].join(".")
    else
      self.subdomain   = ""
      self.base_domain = hostname
    end
  end

  # Distinct upstream hosts already in use, most-used first — suggestions for
  # the form's host field.
  def self.distinct_upstream_hosts
    group(:upstream_host).order(Arel.sql("COUNT(*) DESC")).count.keys
  end

  # Base domains derived from existing hostnames (everything after the first
  # label, for hostnames that actually have a subdomain), most-common first.
  def self.derived_base_domains
    pluck(:hostname)
      .filter_map { |h| h.split(".")[1..].join(".") if h.to_s.count(".") >= 2 }
      .tally
      .sort_by { |_value, count| -count }
      .map(&:first)
  end

  private

  # Build hostname from the virtual subdomain/base_domain when the form supplied
  # them. A blank subdomain yields the bare base domain (apex).
  def compose_hostname
    return if subdomain.nil? && base_domain.nil?

    parts = [ subdomain.to_s.strip.presence, base_domain.to_s.strip.presence ].compact
    self.hostname = parts.join(".")
  end

  def normalize_hostname
    self.hostname = hostname.to_s.strip.downcase.presence
  end

  # Auto-name from the subdomain (or the hostname's first label) when no name
  # was given: "caramba" => "Caramba", "media-server" => "Media Server".
  def backfill_name
    return if name.present?

    label = subdomain.presence || hostname.to_s.split(".").first
    self.name = label.to_s.tr("-_", " ").split.map(&:capitalize).join(" ").presence
  end
end

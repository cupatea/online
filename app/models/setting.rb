class Setting < ApplicationRecord
  has_secure_password :admin_password, validations: false

  # Singleton — there is only ever one row. Use Setting.instance to access it.
  validates :acme_email, presence: true,
                         format: { with: URI::MailTo::EMAIL_REGEXP },
                         if: :configured?
  validates :cloudflare_token, presence: true, if: :configured?
  validates :admin_password, length: { minimum: 12 }, allow_nil: true

  def self.instance
    first_or_create!
  end

  def configured?
    acme_email.present? || cloudflare_token.present?
  end

  def complete?
    acme_email.present? && cloudflare_token.present?
  end

  def admin_password_configured?
    admin_password_digest.present?
  end

  def change_admin_password!(password)
    update!(admin_password: password)
  end

  # Preset lists for the service form. One entry per line; the first line is the
  # preselected default. Used as datalist suggestions, merged with values
  # derived from existing services.
  def upstream_host_list = list_from(upstream_hosts)
  def base_domain_list   = list_from(base_domains)

  private

  def list_from(text)
    text.to_s.split("\n").map(&:strip).reject(&:empty?).uniq
  end
end

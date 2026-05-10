class Setting < ApplicationRecord
  # Singleton — there is only ever one row. Use Setting.instance to access it.
  validates :acme_email, presence: true,
                         format: { with: URI::MailTo::EMAIL_REGEXP },
                         if: :configured?
  validates :cloudflare_token, presence: true, if: :configured?

  def self.instance
    first_or_create!
  end

  def configured?
    acme_email.present? || cloudflare_token.present?
  end

  def complete?
    acme_email.present? && cloudflare_token.present?
  end
end

require "bcrypt"

module AdminPassword
  module_function

  def configured?
    digest.present?
  end

  def matches?(password)
    return false if password.blank? || !configured?

    BCrypt::Password.new(digest).is_password?(password)
  rescue BCrypt::Errors::InvalidHash
    false
  end

  def digest
    @digest ||= begin
      configured_digest = secret_from("ADMIN_PASSWORD_DIGEST")
      initial_password = secret_from("ADMIN_PASSWORD")

      if configured_digest.present?
        configured_digest
      elsif initial_password.present?
        BCrypt::Password.create(initial_password)
      end
    end
  end

  def secret_from(name)
    file = ENV["#{name}_FILE"]
    return File.read(file).strip if file.present?

    ENV[name].to_s.strip
  rescue Errno::ENOENT, Errno::EACCES
    nil
  end
end

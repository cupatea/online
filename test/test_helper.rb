ENV["RAILS_ENV"] ||= "test"
ENV["ADMIN_PASSWORD"] = "correct horse battery staple"

require_relative "../config/environment"
require "rails/test_help"

module AdminAuthenticationTestHelper
  ADMIN_PASSWORD = ENV.fetch("ADMIN_PASSWORD")

  def sign_in_as_admin
    post admin_login_path, params: { password: ADMIN_PASSWORD }
    assert_response :redirect
  end
end

class ActiveSupport::TestCase
  parallelize(workers: 1)

  setup do
    Rails.cache.clear
    AdminPassword.remove_instance_variable(:@digest) if AdminPassword.instance_variable_defined?(:@digest)
  end
end

class ActionDispatch::IntegrationTest
  include AdminAuthenticationTestHelper
end

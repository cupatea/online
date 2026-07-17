ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"

module AdminAuthenticationTestHelper
  ADMIN_PASSWORD = "correct horse battery staple"

  def sign_in_as_admin
    Setting.instance.change_admin_password!(ADMIN_PASSWORD)
    post admin_login_path, params: { password: ADMIN_PASSWORD }
    assert_response :redirect
  end
end

class ActiveSupport::TestCase
  parallelize(workers: 1)

  setup do
    Rails.cache.clear
  end
end

class ActionDispatch::IntegrationTest
  include AdminAuthenticationTestHelper
end

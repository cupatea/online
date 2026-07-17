require "test_helper"
class AdminAuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    Setting.instance.change_admin_password!(ADMIN_PASSWORD)
  end

  test "dashboard is public" do
    local_address = Struct.new(:ip_port).new(30_004)
    socket = Object.new
    socket.define_singleton_method(:to_io) { self }
    socket.define_singleton_method(:local_address) { local_address }
    previous_port = ENV["DASHBOARD_PORT"]
    ENV["DASHBOARD_PORT"] = local_address.ip_port.to_s

    get dashboard_path, env: { "puma.socket" => socket }

    assert_response :success
  ensure
    ENV["DASHBOARD_PORT"] = previous_port
  end

  test "public profile is available without authentication" do
    profile = Profile.create!(name: "Public")

    get profile_path(profile)

    assert_response :success
  end

  test "protected GET redirects to login" do
    get setting_path

    assert_redirected_to admin_login_path
  end

  test "every unauthenticated mutation is rejected" do
    requests = [
      -> { post profiles_path, params: { profile: { name: "Nope" } } },
      -> { post services_path, params: { service: { name: "Nope" } } },
      -> { patch service_path(123), params: { service: { name: "Nope" } } },
      -> { put service_path(123), params: { service: { name: "Nope" } } },
      -> { delete service_path(123) },
      -> { patch setting_path, params: { setting: { acme_email: "nope@example.com" } } },
      -> { post republish_path }
    ]

    requests.each do |request|
      request.call
      assert_response :unauthorized
    end
  end

  test "login creates a session that authorizes later requests" do
    get setting_path
    assert_redirected_to admin_login_path

    post admin_login_path, params: { password: ADMIN_PASSWORD }
    assert_redirected_to setting_path

    get setting_path
    assert_response :success
  end

  test "first login creates the admin password and signs in" do
    Setting.instance.update_column(:admin_password_digest, nil)

    get admin_login_path
    assert_response :success
    assert_select "h1", "Create admin password"

    post admin_login_path, params: {
      password: ADMIN_PASSWORD,
      password_confirmation: ADMIN_PASSWORD
    }

    assert_response :redirect
    assert Setting.instance.reload.authenticate_admin_password(ADMIN_PASSWORD)
  end

  test "first login requires matching confirmation" do
    Setting.instance.update_column(:admin_password_digest, nil)

    post admin_login_path, params: {
      password: ADMIN_PASSWORD,
      password_confirmation: "different password"
    }

    assert_response :unprocessable_entity
    assert_not Setting.instance.reload.admin_password_configured?
  end

  test "invalid login is rejected" do
    post admin_login_path, params: { password: "wrong" }

    assert_response :unprocessable_entity
    assert_select ".alert", text: /Incorrect password/
  end

  test "login is rate limited" do
    5.times do
      post admin_login_path, params: { password: "wrong" }
      assert_response :unprocessable_entity
    end

    post admin_login_path, params: { password: "wrong" }

    assert_redirected_to admin_login_path
    assert_equal "Too many attempts. Try again in a minute.", flash[:alert]
  end
end

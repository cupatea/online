require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @setting = Setting.instance
    @setting.update!(
      acme_email: "admin@example.com",
      cloudflare_token: "old-token",
      admin_password: ADMIN_PASSWORD
    )
    sign_in_as_admin
  end

  test "token is visible only on the authenticated settings page" do
    get setting_path

    assert_response :success
    assert_select "input[name='setting[cloudflare_token]'][type='password'][value='old-token']"
  end

  test "changing Cloudflare token requires password confirmation" do
    patch setting_path, params: {
      setting: {
        acme_email: @setting.acme_email,
        cloudflare_token: "new-token",
        upstream_hosts: @setting.upstream_hosts,
        base_domains: @setting.base_domains
      }
    }

    assert_response :unprocessable_entity
    assert_equal "old-token", @setting.reload.cloudflare_token
  end

  test "changing Cloudflare token accepts the current password" do
    original_publish = CaddyPublisher.method(:publish!)
    CaddyPublisher.define_singleton_method(:publish!) { [ true, "Published." ] }

    begin
      patch setting_path, params: {
        setting: {
          acme_email: @setting.acme_email,
          cloudflare_token: "new-token",
          current_password: ADMIN_PASSWORD,
          upstream_hosts: @setting.upstream_hosts,
          base_domains: @setting.base_domains
        }
      }
    ensure
      CaddyPublisher.define_singleton_method(:publish!, original_publish)
    end

    assert_response :redirect
    assert_equal "new-token", @setting.reload.cloudflare_token
  end
end

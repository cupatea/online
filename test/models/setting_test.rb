require "test_helper"

class SettingTest < ActiveSupport::TestCase
  test "change_admin_password stores a bcrypt digest" do
    setting = Setting.instance

    setting.change_admin_password!("a new secure password")

    assert setting.reload.admin_password_configured?
    assert setting.authenticate_admin_password("a new secure password")
    assert_not_equal "a new secure password", setting.admin_password_digest
  end

  test "admin password must be at least twelve characters" do
    setting = Setting.instance

    assert_not setting.update(admin_password: "too short")
    assert_includes setting.errors[:admin_password], "is too short (minimum is 12 characters)"
  end
end

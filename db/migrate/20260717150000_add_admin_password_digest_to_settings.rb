class AddAdminPasswordDigestToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :admin_password_digest, :string
  end
end

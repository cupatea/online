class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.string :acme_email,       null: false, default: ""
      t.string :cloudflare_token, null: false, default: ""

      t.timestamps
    end
  end
end

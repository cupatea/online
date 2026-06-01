class AddEnabledToLinks < ActiveRecord::Migration[8.1]
  def change
    add_column :links, :enabled, :boolean, default: true, null: false
  end
end

class AddDashboardFieldsToServices < ActiveRecord::Migration[8.1]
  def change
    add_column :services, :icon, :string
    add_column :services, :description, :string
  end
end

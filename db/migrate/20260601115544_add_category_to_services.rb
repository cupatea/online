class AddCategoryToServices < ActiveRecord::Migration[8.1]
  def change
    add_column :services, :category, :string, default: "general", null: false
  end
end

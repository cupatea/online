class AddCategoryToLinks < ActiveRecord::Migration[8.1]
  def change
    add_column :links, :category, :string
  end
end

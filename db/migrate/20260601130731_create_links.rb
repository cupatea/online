class CreateLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :links do |t|
      t.references :profile, null: false, foreign_key: true
      t.string :title, null: false
      t.string :description
      t.string :icon
      t.string :url, null: false
      t.integer :position

      t.timestamps
    end
  end
end

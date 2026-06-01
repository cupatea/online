class CreateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :profiles do |t|
      t.string :name, null: false
      t.string :slug, null: false

      t.timestamps
    end
    add_index :profiles, :slug, unique: true
  end
end

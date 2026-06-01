class MigrateLinkCategoriesToRecords < ActiveRecord::Migration[8.1]
  def up
    create_table :categories do |t|
      t.references :profile, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position
      t.timestamps
    end
    add_index :categories, [ :profile_id, :name ], unique: true
    add_reference :links, :category, foreign_key: true

    # Backfill: turn each distinct (profile, category string) into a Category
    # record and point its links at it. Raw SQL to avoid depending on models.
    select_all("SELECT id FROM profiles").rows.flatten.each do |profile_id|
      names = select_all(
        "SELECT DISTINCT category FROM links " \
        "WHERE profile_id = #{profile_id.to_i} AND category IS NOT NULL AND category != ''"
      ).rows.flatten
      names.each_with_index do |name, i|
        n = quote(name)
        execute "INSERT INTO categories (profile_id, name, position, created_at, updated_at) " \
                "VALUES (#{profile_id.to_i}, #{n}, #{i}, datetime('now'), datetime('now'))"
        cat_id = select_value("SELECT id FROM categories WHERE profile_id = #{profile_id.to_i} AND name = #{n}")
        execute "UPDATE links SET category_id = #{cat_id.to_i} WHERE profile_id = #{profile_id.to_i} AND category = #{n}"
      end
    end

    remove_column :links, :category
  end

  def down
    add_column :links, :category, :string
    select_all("SELECT id, name FROM categories").each do |row|
      execute "UPDATE links SET category = #{quote(row['name'])} WHERE category_id = #{row['id'].to_i}"
    end
    remove_reference :links, :category
    drop_table :categories
  end
end

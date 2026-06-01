class AddPresetsToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :upstream_hosts, :text, default: "", null: false
    add_column :settings, :base_domains, :text, default: "", null: false
  end
end

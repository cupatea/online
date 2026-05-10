class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.string  :name,          null: false
      t.string  :hostname,      null: false
      t.string  :upstream_host, null: false, default: "localhost"
      t.integer :upstream_port, null: false
      t.boolean :enabled,       null: false, default: true

      t.timestamps
    end

    add_index :services, :hostname, unique: true
  end
end

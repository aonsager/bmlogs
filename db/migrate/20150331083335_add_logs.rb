class AddLogs < ActiveRecord::Migration
  def change
    create_table :logs, id: false do |t|
      t.string   :id, null: false
      t.string   :title
      t.integer  :zone
      t.datetime :started_at
      t.datetime :ended_at
      t.timestamps
    end

    add_index :logs, :id, :unique => true
  end
end

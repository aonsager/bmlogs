class AddEncounters < ActiveRecord::Migration
  def change
    create_table :zones do |t|
      t.string   :name
      t.timestamps
    end

    create_table :bosses do |t|
      t.string   :name
      t.string   :zone_id
      t.timestamps
    end
  end
end

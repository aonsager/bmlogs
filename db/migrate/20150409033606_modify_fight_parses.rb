class ModifyFightParses < ActiveRecord::Migration
  def change
    add_column :fight_parses, :guard_absorbed, :integer, default: 0
    add_column :fight_parses, :guard_healed, :integer, default: 0
    add_column :fight_parses, :eb_avoided, :integer, default: 0
    add_column :fight_parses, :dh_reduced, :integer, default: 0
    add_column :fight_parses, :dm_reduced, :integer, default: 0
    add_column :fight_parses, :zm_reduced, :integer, default: 0
    add_column :fight_parses, :fb_reduced, :integer, default: 0
  end
end

class ModifyFightParse < ActiveRecord::Migration
  def change
    remove_index :fight_parses, :fight_id
    add_index :fight_parses, [:fight_id, :player_id], :unique => true
  end
end

class AddFightParses < ActiveRecord::Migration
  def change
    create_table :fight_parses do |t|
      t.integer  :fight_id, null: false
      t.text     :user_id, null: false
      t.integer  :player_id, null: false
      t.integer  :boss_id
      t.integer  :kegsmash, default: 0
      t.integer  :tigerpalm, default: 0
      t.integer  :shuffle, default: 0
      t.integer  :capped_time, default: 0
      t.integer  :damage_to_stagger, default: 0
      t.integer  :damage_from_stagger, default: 0
      t.integer  :player_damage_done, default: 0
      t.integer  :pet_damage_done, default: 0
      t.integer  :damage_taken, default: 0
      t.integer  :self_healing, default: 0
      t.integer  :self_absorbing, default: 0
      t.integer  :external_healing, default: 0
      t.integer  :external_absorbing, default: 0
      t.integer  :guard_absorbed, default: 0
      t.integer  :guard_healed, default: 0
      t.integer  :eb_avoided, default: 0
      t.integer  :dh_reduced, default: 0
      t.integer  :dm_reduced, default: 0
      t.integer  :zm_reduced, default: 0
      t.integer  :fb_reduced, default: 0
      t.integer  :started_at
      t.integer  :ended_at
      t.timestamps
    end

    create_table :cooldown_parses do |t|
      t.integer  :fight_parse_id, null: false
      t.integer  :cooldown_type, null: false
      t.integer  :absorbed_amount, default: 0
      t.integer  :healed_amount, default: 0
      t.integer  :reduced_amount, default: 0
      t.text     :ability_hash, default: {}.to_yaml
      t.integer  :started_at
      t.integer  :ended_at
      t.timestamps
    end

    add_index :fight_parses, [:fight_id, :player_id], :unique => true
  end
end
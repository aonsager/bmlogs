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
      t.integer  :started_at
      t.integer  :ended_at
      t.timestamps
    end

    create_table :guard_parses do |t|
      t.integer  :fight_parse_id, null: false
      t.integer  :absorbed, default: 0
      t.integer  :healed, default: 0
      t.integer  :started_at
      t.integer  :ended_at
      t.timestamps
    end

    create_table :eb_parses do |t|
      t.integer  :fight_parse_id, null: false
      t.text     :dodged_hash, default: {}.to_yaml
      t.integer  :started_at
      t.integer  :ended_at
      t.timestamps
    end

    create_table :eb_sources do |t|
      t.integer  :fight_parse_id, null: false
      t.integer  :source_id, null: false
      t.text     :source_name
      t.integer  :ability_id, null: false
      t.text     :ability_name
      t.integer  :average_dmg, default: 0
    end

    add_index :fight_parses, [:fight_id, :player_id], :unique => true
    add_index :eb_sources, [:fight_parse_id, :source_id, :ability_id], :unique => true
  end
end
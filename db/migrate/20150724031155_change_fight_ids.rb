class ChangeFightIds < ActiveRecord::Migration
  def change
    add_column :fights, :fight_hash, :string
    add_index :fights, :fight_hash, :unique => true

    add_column :fight_parses, :fight_hash, :string

    Fight.all.each{|fight| fight.assign_unique_hash; fight.save!}
    FightParse.all.each{|fp| fp.fight_hash = fp.fight.fight_hash; fp.save!}
  end
end

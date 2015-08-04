namespace :fix do
  task :fp => :environment do
    FightParse.all.each do |fp|
      fp.guard_absorbed = fp.calc_guard_total[:absorbed]
      fp.guard_healed = fp.calc_guard_total[:healed]
      fp.eb_avoided = fp.calc_eb_total
      fp.save
    end
  end

  task :eb => :environment do
    EbParse.all.each do |eb|
      eb.total_avoided = 0
      eb.dodged_hash.each do |source_id, source|
        source[:abilities].each do |ability_id, ability|
          avoided_dmg = ability[:dodged] * EbSource.find_by(fight_parse_id: eb.fight_parse_id, source_id: source_id, ability_id: ability_id).average_dmg
          eb.total_avoided += avoided_dmg
        end
      end
      eb.save
    end
  end
end
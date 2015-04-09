namespace :fix do
  task :fp => :environment do
    FightParse.all.each do |fp|
      fp.guard_absorbed = fp.calc_guard_total[:absorbed]
      fp.guard_healed = fp.calc_guard_total[:healed]
      fp.eb_avoided = fp.calc_eb_total
      fp.save
    end
  end
end
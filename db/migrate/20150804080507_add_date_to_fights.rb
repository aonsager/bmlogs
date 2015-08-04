class AddDateToFights < ActiveRecord::Migration
  def change
    add_column :fights, :report_started_at, :datetime
    add_column :fight_parses, :report_started_at, :datetime

    Report.all.each do |report|
      report.fights.each do |fight|
        fight.update_attributes(report_started_at: report.started_at)
        fight.fight_parses.each do |fp|
          fp.update_attributes(report_started_at: report.started_at)
        end
      end
    end
  end
end

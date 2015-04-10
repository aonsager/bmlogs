class GuardParse < ActiveRecord::Base
  belongs_to :fight_parse
  serialize :damage_hash, Hash

  def self.total_guard(fight_parse_id)
    total = 0
    GuardParse.where(fight_parse_id: fight_parse_id).each do |g|
      total += g.absorbed + g.healed / 1.3
    end
    return total.to_i
  end

  def start_time
    seconds = (self.started_at - self.fight_parse.started_at) / 1000
    return "#{seconds / 60}:#{(seconds % 60).to_s.rjust(2, "0")}"
  end

  def end_time
    seconds = (self.ended_at - self.fight_parse.started_at) / 1000
    return "#{seconds / 60}:#{(seconds % 60).to_s.rjust(2, "0")}"
  end

  def time_s
    return "#{self.start_time} - #{self.end_time}"
  end
end
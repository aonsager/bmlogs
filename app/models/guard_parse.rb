class GuardParse < ActiveRecord::Base
  belongs_to :fight_parse

  def self.total_guard(fight_parse_id)
    total = 0
    GuardParse.where(fight_parse_id: 4).each do |g|
      total += g.absorbed + g.healed / 1.3
    end
    return total.to_i
  end
end
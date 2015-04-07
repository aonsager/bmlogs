class EbSource < ActiveRecord::Base
  belongs_to :fight_parse

  def avoided_dmg
    return self.average_dmg * self.dodged_count
  end
end
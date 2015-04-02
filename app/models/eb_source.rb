class EbSource < ActiveRecord::Base
  belongs_to :eb_parse

  def avoided_dmg
    return self.average_dmg * self.dodged_count
  end
end
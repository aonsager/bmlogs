class EbParse < ActiveRecord::Base
  belongs_to :fight_parse
  serialize :dodged_hash, Hash

end
class EbParse < ActiveRecord::Base
  belongs_to :fight_parse
  has_many :eb_source, dependent: :destroy
end
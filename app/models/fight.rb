class Fight < ActiveRecord::Base
  belongs_to :report
  has_many :fight_parse, dependent: :destroy
end
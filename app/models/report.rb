class Report < ActiveRecord::Base
  has_many :fights, dependent: :destroy
end
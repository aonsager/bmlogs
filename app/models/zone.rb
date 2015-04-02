class Zone < ActiveRecord::Base
  has_many :bosses, dependent: :destroy
end
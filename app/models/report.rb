class Report < ActiveRecord::Base
  has_many :fights, primary_key: 'report_id', dependent: :destroy

  def fights_for_select
    return Fight.where(report_id: self.report_id).order(:id).map{|f| [f.full_name, f.fight_hash_if_parsed]}
  end
end
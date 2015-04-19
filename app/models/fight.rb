class Fight < ActiveRecord::Base
  belongs_to :report
  has_many :fight_parses, dependent: :destroy
  enum status: [:fresh, :processing, :done, :failed]

  def button_html
    case self.status
    when 'fresh'
      return ActionController::Base.helpers.link_to('Process Fight', Rails.application.routes.url_helpers.report_fight_parse_path(self.report_id, self.fight_id), class: 'btn btn-default')
    when 'processing'
      return ActionController::Base.helpers.link_to('Processing...', '#', class: 'btn btn-warning', disabled: 'disabled')
    when 'done'
      return ActionController::Base.helpers.link_to('View Fight', Rails.application.routes.url_helpers.fight_path(self.id), class: 'btn btn-success')
    else
      return ActionController::Base.helpers.link_to('Failed :(', '#', class: 'btn btn-error', disabled: 'disabled')
    end
  end
end
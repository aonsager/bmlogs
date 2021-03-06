class Fight < ActiveRecord::Base
  belongs_to :report
  has_many :fight_parses, dependent: :destroy
  enum status: [:fresh, :processing, :done, :failed, :empty]
  before_create :assign_unique_hash

  def button_html(force = nil)
    if self.status == 'processing' # in progress has priority
      return ActionController::Base.helpers.link_to('Processing...', '#', class: 'btn btn-warning', disabled: 'disabled')
    end
    
    case force || self.status
    when 'fresh'
      return ActionController::Base.helpers.link_to('Unprocessed', '#', class: 'btn btn-error', disabled: 'disabled')
    when 'done'
      return ActionController::Base.helpers.link_to('View Fight', Rails.application.routes.url_helpers.fight_path(self.fight_hash), class: 'btn btn-success')
    when 'empty'
      return ActionController::Base.helpers.link_to('No Brewmasters found', '#', class: 'btn btn-error', disabled: 'disabled')
    else
      return ActionController::Base.helpers.link_to('Failed :(', '#', class: 'btn btn-error', disabled: 'disabled')
    end
  end

  def full_name
    fp = self.fight_parses.first
    if fp.nil?
      return self.name
    else
      return self.name + " (#{fp.fight_time / 60}:#{fp.fight_time % 60})"
    end
  end

  def fight_hash_if_parsed
    if self.status == 'done'
      return self.fight_hash
    else
      return nil
    end
  end

  def assign_unique_hash
    self.fight_hash = SecureRandom.hex(8) until unique_hash?
  end

  def unique_hash?
    self.class.where(fight_hash: self.fight_hash).count == 0
  end
end
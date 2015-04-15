class FightsController < ApplicationController

  def parse
    fight_id = params[:fight_id] || params[:id]
    report_id = params[:report_id]
    Resque.enqueue(Parser, fight_id, report_id)
    Fight.where(report_id: report_id, fight_id: fight_id).first.update_attributes(status: 1)

    redirect_to report_path(report_id)
  end

  def show
    @fight_id = params[:id]
    @player_id = params[:player_id]
    @fight = Fight.where(id: @fight_id).first
    @report = Report.where(report_id: @fight.report_id).first
    @fp = FightParse.where(fight_id: @fight_id).first

    case params[:tab]
    when 'resources'
      render template: 'fights/show_resources'
    when 'cooldowns'
      @max_guard = 1
      @max_eb = @fp.eb_parses.maximum(:total_avoided)
      @fp.guard_parses.each {|g| @max_guard = (g.absorbed + g.healed) if (g.absorbed + g.healed) > @max_guard}
      render template: 'fights/show_cooldowns'
    else
      render template: 'fights/show_basic'
    end
  end
end

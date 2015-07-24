class FightsController < ApplicationController

  def parse
    fight_id = params[:fight_id] || params[:id]
    report_id = params[:report_id]
    Resque.enqueue(Parser, fight_id, report_id)
    Fight.where(report_id: report_id, fight_id: fight_id).first.update_attributes(status: :processing)
    flash[:success] = "Your report has been queued. Please try refreshing the page in a few minutes."
    redirect_to report_path(report_id)
  end

  def show
    fight_hash = params[:id]
    @player_id = params[:player_id]
    @fight = Fight.find_by(fight_hash: fight_hash)
    @report = Report.find_by(report_id: @fight.report_id)
    @fps = @fight.fight_parses.to_a

    case params[:tab]
    when 'resources'
      render template: 'fights/show_resources'
    when 'cooldowns'
      @max_guard = 1
      @max_eb = 1
      @max_dh = 1
      @max_dm = 1
      @max_zm = 1
      @max_fb = 1
      @max_bar = 1
      @fps.each do |fp|
        @max_eb = [fp.cooldown_parses.eb.maximum(:reduced_amount).to_i, @max_eb].max
        @max_dh = [fp.cooldown_parses.dh.maximum(:reduced_amount).to_i, @max_dh].max
        @max_dm = [fp.cooldown_parses.dm.maximum(:reduced_amount).to_i, @max_dm].max
        @max_zm = [fp.cooldown_parses.zm.maximum(:reduced_amount).to_i, @max_zm].max
        @max_fb = [fp.cooldown_parses.fb.maximum(:reduced_amount).to_i, @max_fb].max
        fp.cooldown_parses.guard.each {|g| @max_guard = (g.absorbed_amount + g.healed_amount) if (g.absorbed_amount + g.healed_amount) > @max_guard}
        @max_bar = [fp.gps, fp.ebps, fp.dh_reduced / fp.fight_time, fp.dm_reduced / fp.fight_time, fp.zm_reduced / fp.fight_time, fp.fb_reduced / fp.fight_time, @max_bar].max
      end
      render template: 'fights/show_cooldowns'
    else
      @max_bar = 1
      @fps.each do |fp|
        @max_bar = [fp.dps, fp.dtps, fp.shps, fp.ehps, @max_bar].max
      end
      render template: 'fights/show_basic'
    end
  end
end

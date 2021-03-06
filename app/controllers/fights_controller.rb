class FightsController < ApplicationController

  # def parse
  #   fight_id = params[:fight_id] || params[:id]
  #   report_id = params[:report_id]
  #   Resque.enqueue(Parser, fight_id, report_id)
  #   Fight.find_by(report_id: report_id, fight_id: fight_id).update_attributes(status: :processing)
  #   flash[:success] = "Your report has been queued. Please try refreshing the page in a few minutes."
  #   redirect_to report_path(report_id)
  # end

  def show
    fight_hash = params[:id]
    @fight = Fight.find_by(fight_hash: fight_hash)
    @report = Report.find_by(report_id: @fight.report_id)
    @fps = @fight.fight_parses.order(:player_id).to_a
    @players = UserToPlayer.where(player_id: @fps.map(&:player_id)).order(:player_id).to_a
    @players = @players.uniq{|p| p.player_id}
    @fights = @report.fights_for_select

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
        @max_dh = [fp.cooldown_parses.dh.maximum(:reduced_amount).to_i, @max_dh].max
        @max_dm = [fp.cooldown_parses.dm.maximum(:reduced_amount).to_i, @max_dm].max
        @max_zm = [fp.cooldown_parses.zm.maximum(:reduced_amount).to_i, @max_zm].max
        @max_fb = [fp.cooldown_parses.fb.maximum(:reduced_amount).to_i, @max_fb].max
        fp.cooldown_parses.eb.each {|eb| @max_eb = (eb.reduced_amount / eb.time) if (eb.reduced_amount / eb.time) > @max_eb}
        fp.cooldown_parses.guard.each {|g| @max_guard = (g.absorbed_amount + g.healed_amount) if (g.absorbed_amount + g.healed_amount) > @max_guard}
        @max_bar = [fp.gps, fp.ebps, fp.dh_reduced / fp.fight_time, fp.dm_reduced / fp.fight_time, fp.zm_reduced / fp.fight_time, fp.fb_reduced / fp.fight_time, @max_bar].max
      end
      render template: 'fights/show_cooldowns'
    when 'hp'
      render template: 'fights/show_hp'
    else
      @max_bar = 1
      @fps.each do |fp|
        @max_bar = [fp.dps, fp.dtps, fp.shps, fp.ehps, @max_bar].max
      end
      render template: 'fights/show_basic'
    end
  end

  def load_hp_graph
    fight_hash = params[:fight_id]
    @fight = Fight.find_by(fight_hash: fight_hash)
    @fps = @fight.fight_parses.order(:player_id).to_a
    @hp_parses = {}
    @fps.each do |fp|
      file = S3_BUCKET.object("#{fp.fight_hash}_#{fp.player_id}_hp.json")
      if file.exists?
        @hp_parses[fp.player_id] = JSON.parse(file.get.body.string)
        @hp_parses[fp.player_id]['base_hp'] = []
        @hp_parses[fp.player_id]['hp'].each_with_index do |hash, index|
          @hp_parses[fp.player_id]['base_hp'][index] = [hash[0], hash[1] - @hp_parses[fp.player_id]['self_heal'][index][1] - @hp_parses[fp.player_id]['external_heal'][index][1]]
        end
      end
    end

    respond_to do |format|
      format.js
    end
  end
end

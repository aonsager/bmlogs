class FightsController < ApplicationController
  before_filter :get_fight

  def parse
    response = HTTParty.get("https://www.warcraftlogs.com/v1/report/events/#{@report_id}?start=#{@fight.started_at}&api_key=#{ENV['API_KEY']}")
    obj = JSON.parse(response.body)
    composition = obj['composition']
    events = obj['events']
    @parsed_events = {}

    composition.each do |player|
      @parsed_events[player['id']] = [] if player['specs'][0]['spec'] == "Brewmaster"
    end

    events.each do |event|
      next unless @parsed_events.has_key? event['targetID']
      @parsed_events[event['targetID']] << event
    end

    # fights.each do |fight|
    #   next if fight['boss'].to_i == 0
    #   if !Fight.exists?(report_id: @report_id, fight_id: fight['id'])
    #     Fight.create(
    #       report_id: @report_id,
    #       fight_id: fight['id'],
    #       name: fight['name'],
    #       boss_id: fight['boss'],
    #       size: fight['size'],
    #       difficulty: fight['difficulty'],
    #       kill: fight['kill'],
    #       started_at: fight['start_time'],
    #       ended_at: fight['end_time'],
    #     )
    #   end
    # end
    # players.each do |player|
    #   if !Player.exists?(report_id: @report_id, player_id: player['id'])
    #     Player.create(
    #       report_id: @report_id,
    #       player_id: player['id'],
    #       guid: player['guid'],
    #       name: player['name'],
    #       player_class: player['type']
    #     )
    #   end
    # end

    # Report.where(report_id: @report_id).first.update_attribute(:imported, true)

    # redirect_to user_report_fight_path(@user_id, @report_id, @fight_id)
  end

  def show
    @fight = Fight.where(report_id: @report_id, fight_id: @fight_id).first
    @report = Report.where(report_id: @report_id).first
  end

  private

  def get_fight
    @fight_id = params[:fight_id] || params[:id]
    @fight = Fight.where(fight_id: @fight_id).first
    @report_id = params[:report_id]
    @user_id = params[:user_id]
  end
end

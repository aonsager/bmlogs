class PlayersController < ApplicationController

  def index
    @user_id = params[:user_id]
    @players = UserToPlayer.where(user_id: @user_id)
    @report_counts = FightParse.where(user_id: @user_id).group(:player_id).count.with_indifferent_access
  end

  def show
    @player_id = params[:id] || params[:player_id]
    @player_name = UserToPlayer.find_by(player_id: @player_id).player_name
    @zones = Zone.all.order('id DESC').includes(:bosses)
    @player_bosses = {}
    FightParse.where(player_id: @player_id).each do |fp|
      @player_bosses[fp.boss_id] = {} unless @player_bosses.has_key?(fp.boss_id)
      @player_bosses[fp.boss_id][fp.difficulty] = 0 unless @player_bosses[fp.boss_id].has_key?(fp.difficulty)
      @player_bosses[fp.boss_id][fp.difficulty] += 1
    end
  end

  def search
    @char_name = params[:char_name]
    @chars = UserToPlayer.where("player_name ILIKE ?", @char_name).to_a
    @report_counts = FightParse.where(player_id: @chars.map(&:player_id)).group(:player_id).count.with_indifferent_access
  end
end

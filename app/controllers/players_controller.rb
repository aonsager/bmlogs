class PlayersController < ApplicationController

  def index
    @user_id = params[:user_id]
    @players = UserToPlayer.where(user_id: @user_id)
    @report_counts = FightParse.where(user_id: @user_id).group(:player_id).count.with_indifferent_access
  end

  def show
    @player_id = params[:id] || params[:player_id]
    @player_name = UserToPlayer.where(player_id: @player_id).first.player_name
    @zones = Zone.all.order('id DESC')
    @player_bosses = FightParse.where(player_id: @player_id).group(:boss_id).count
  end
end

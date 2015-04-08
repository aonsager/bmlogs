class BossesController < ApplicationController
  def show
    @player_id = params[:player_id]
    @player_name = UserToPlayer.where(player_id: @player_id).first.player_name
    @boss_id = params[:id]
    @boss_name = Boss.find(@boss_id).name

    @fights = FightParse.where(player_id: @player_id, boss_id: @boss_id)
    @max_dps = 0
    @max_dtps = 0
    @max_shps = 0
    @max_ehps = 0
    @fights.each do |f|
      @max_dps = f.dps if f.dps > @max_dps
      @max_dtps = f.dtps if f.dtps > @max_dtps
      @max_shps = f.shps if f.shps > @max_shps
      @max_ehps = f.ehps if f.ehps > @max_ehps
    end
  end
end
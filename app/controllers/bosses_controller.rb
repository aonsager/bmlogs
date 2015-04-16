class BossesController < ApplicationController
  def show
    @player_id = params[:player_id]
    @player_name = UserToPlayer.where(player_id: @player_id).first.player_name
    @boss_id = params[:id]
    @boss_name = Boss.find(@boss_id).name

    @fights = FightParse.where(player_id: @player_id, boss_id: @boss_id)

    case params[:tab]
    when 'resources'
      render template: 'bosses/show_resources'
    when 'cooldowns'
      @max_gps = 0
      @max_ebps = 0
      @max_dhps = 0
      @max_dmps = 0
      @max_zmps = 0
      @max_fbps = 0
      @fights.each do |f|
        @max_gps = f.gps if f.gps > @max_gps
        @max_ebps = f.ebps if f.ebps > @max_ebps
        @max_dhps = (f.dh_reduced / f.fight_time) if (f.dh_reduced / f.fight_time) > @max_dhps
        @max_dmps = (f.dm_reduced / f.fight_time) if (f.dm_reduced / f.fight_time) > @max_dmps
        @max_zmps = (f.zm_reduced / f.fight_time) if (f.zm_reduced / f.fight_time) > @max_zmps
        @max_fbps = (f.fb_reduced / f.fight_time) if (f.fb_reduced / f.fight_time) > @max_fbps
      end
      render template: 'bosses/show_cooldowns'
    else
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
      render template: 'bosses/show_basic'
    end
  end
end
class FightsController < ApplicationController

  def parse
    @fight_id = params[:fight_id] || params[:id]
    @report_id = params[:report_id]
    @fight = Fight.where(report_id: @report_id, fight_id: @fight_id).first
    @user_id = params[:user_id]
    debug = false

    response = HTTParty.get("https://www.warcraftlogs.com/v1/report/events/#{@report_id}?start=#{@fight.started_at}&api_key=#{ENV['API_KEY']}")
    obj = JSON.parse(response.body)
    composition = obj['composition']
    events = obj['events']
    bm_ids = {}
    fight_parses = {}
    owners_by_pet_id = {}
    user_id = Report.where(report_id: @fight.report_id).first.user_id

    composition.each do |player|
      puts player if debug
      bm_ids[player['id']] = {guid: player['guid'], name: player['name']} if player['specs'][0]['spec'] == "Brewmaster"
    end

    puts bm_ids if debug

    bm_ids.each do |bm_id, bm_hash|
      u2p = UserToPlayer.where(user_id: user_id, player_id: bm_hash[:guid]).first_or_initialize
      u2p.update_attributes(player_name: bm_hash[:name])
      FightParse.where(fight_id: @fight.id, user_id: user_id, player_id: bm_hash[:guid]).destroy_all
      fight_parses[bm_id] = FightParse.create(fight_id: @fight.id, user_id: user_id, player_id: bm_hash[:guid], boss_id: @fight.boss_id)
      fight_parses[bm_id].started_at = @fight.started_at
      fight_parses[bm_id].ended_at = @fight.ended_at
    end

    loop do
      cursor = @fight.started_at
      events.each do |event|
        if bm_ids.has_key?(event['sourceID']) # the player did something
          puts event if debug
          fp = fight_parses[event['sourceID']]
          case event['type']
          when 'cast'
            fp.cast_kegsmash if event['ability']['guid'] == 121253
            fp.cast_tigerpalm if event['ability']['guid'] == 100787
            # puts "#{event['resourceActor']}, #{event['resourceAmount']}, #{event['maxResourceAmount']}, #{event['resourceType']}"
            if event['resourceType'] == 3 # check if energy capped
              if event['resourceAmount'] == event['maxResourceAmount']
                fp.cap(true, event['timestamp']) unless (fp.capped || fp.serenity)
              elsif fp.capped
                fp.cap(false, event['timestamp'])
              end
            end
          when 'applybuff'
            case event['ability']['guid'] 
            when 115295 # gain guard
              fp.gain_guard(event['timestamp'])
            when 115307 # gain shuffle
              fp.gain_shuffle(event['timestamp'])
            when 115308 # gain elusive brew
              fp.gain_eb(event['timestamp'])
            when 152173 # gain serenity
              fp.serenity = true
            end
          when 'removebuff'
            case event['ability']['guid'] 
            when 115295 # drop guard
              fp.drop_guard(event['timestamp'])
            when 115307 # drop shuffle
              fp.drop_shuffle(event['timestamp'])
            when 115308 # drop elusive brew
              fp.drop_eb(event['timestamp'])
            when 152173 # drop serenity
              fp.serenity = false
            end
          when 'damage'
            fp.deal_damage_player(event['amount']) if !event['targetIsFriendly']
            fp.stagger_tick(event['amount'] + event['absorbed']) if event['targetID'] == event['sourceID']
          when 'summon'
            owners_by_pet_id[event['targetID']] ||= event['sourceID']
          end
        end
        if owners_by_pet_id.has_key?(event['sourceID']) # the player's pet did something
          case event['type']
          when 'damage'
            fp = fight_parses[owners_by_pet_id[event['sourceID']]]
            fp.deal_damage_pet(event['amount']) if !event['targetIsFriendly']
          end
        end
        if bm_ids.has_key?(event['targetID']) # something was done to the player
          fp = fight_parses[event['targetID']]
          case event['type']
          when 'absorbed'
            if event['targetID'] == event['sourceID'] # self-absorb
              if event['ability']['guid'] == 115069 # stagger
                fp.stagger(event['amount'])
              elsif event['ability']['guid'] == 115295 # guard
                fp.guard(event['amount'])
              else # just in case
                fp.self_absorb(event['amount'])
              end
            else # external absorb received
              fp.external_absorb(event['amount'])
            end
          when 'heal'
            if event['targetID'] == event['sourceID'] # self-healing
              fp.self_heal(event['amount'])
            else # external healing received
              fp.external_heal(event['amount'])
            end
          when 'damage'
            fp.take_damage(event['amount'])
            unless [7,8].include? event['hitType'] # record damage from ability
              fp.record_damage(event['sourceID'], event['ability']['guid'], event['ability']['name'], event['amount'], event['absorbed'])
            end
            if fp.ebing && event['hitType'] == 7 # dodge with elusive brew
              fp.dodge(event['sourceID'], event['ability']['guid'], event['ability']['name'])
            end
          end
        end
        cursor = event['timestamp'] + 1
      end
      puts "cursor: #{cursor}"
      if cursor >=  @fight.ended_at
        break
      else 
        response = HTTParty.get("https://www.warcraftlogs.com/v1/report/events/#{@report_id}?start=#{cursor}&api_key=#{ENV['API_KEY']}")
        obj = JSON.parse(response.body)
        events = obj['events']
      end
    end

    bm_ids.each do |bm_id, guid|
      fight_parses[bm_id].clean
      fight_parses[bm_id].save
      fight_parses[bm_id].print
    end

    redirect_to report_path(@report_id)
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
      @max_guard = 0
      @max_eb = @fp.eb_parses.maximum(:total_avoided)
      @fp.guard_parses.each {|g| @max_guard = (g.absorbed + g.healed) if (g.absorbed + g.healed) > @max_guard}
      render template: 'fights/show_cooldowns'
    else
      render template: 'fights/show_basic'
    end
  end
end

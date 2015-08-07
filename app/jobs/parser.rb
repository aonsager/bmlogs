require 'resque/errors'

class Parser
  @queue = :parse
  @fight_id = 0
  @report_id = 0

  def self.on_failure_reset(e, *args)
    Fight.find_by(report_id: @report_id, fight_id: @fight_id).update_attributes(status: :failed)
  end

  def self.perform(fight_id, report_id)
    @fight_id = fight_id
    @report_id = report_id
    fight = Fight.find_by(report_id: report_id, fight_id: fight_id)
    response = HTTParty.get("https://www.warcraftlogs.com/v1/report/events/#{report_id}?start=#{fight.started_at}&api_key=#{ENV['WCL_API_KEY']}")
    obj = JSON.parse(response.body)
    composition = obj['composition']
    events = obj['events']
    bm_ids = {}
    fight_parses = {}
    owners_by_pet_id = {}
    user_id = Report.find_by(report_id: fight.report_id).user_id

    composition.each do |player|
      next if player['specs'].size == 0 # not sure why sometimes this data doesn't come
      bm_ids[player['id']] = {guid: player['guid'], name: player['name']} if player['specs'][0]['spec'] == "Brewmaster"
    end

    bm_ids.each do |bm_id, bm_hash|
      u2p = UserToPlayer.find_or_initialize_by(player_id: bm_hash[:guid])
      u2p.update_attributes(player_name: bm_hash[:name])
      FightParse.where(fight_id: fight.id, player_id: bm_hash[:guid]).destroy_all
      fight_parses[bm_id] = FightParse.create(fight_id:   fight.id, 
                                              fight_hash: fight.fight_hash, 
                                              player_id: bm_hash[:guid], 
                                              boss_id: fight.boss_id, 
                                              difficulty: fight.difficulty,
                                              report_started_at: fight.report_started_at,
                                              started_at: fight.started_at,
                                              ended_at: fight.ended_at)
    end

    cursor = fight.started_at
    loop do
      break if events == []
      events.each do |event|
        if bm_ids.has_key?(event['sourceID']) # the player did something
          fp = fight_parses[event['sourceID']]
          case event['type']
          when 'cast'
            fp.cast_kegsmash if event['ability']['guid'] == 121253
            fp.cast_tigerpalm if event['ability']['guid'] == 100787
            if event['resourceType'] == 3 # check if energy capped
              if event['resourceAmount'] == event['maxResourceAmount']
                fp.cap(true, event['timestamp']) unless (fp.capped || fp.serenity)
              elsif fp.capped
                fp.cap(false, event['timestamp'])
              end
            end
          when 'applybuff', 'refreshbuff'
            case event['ability']['guid'] 
            when 115295 # gain guard
              fp.gain_cooldown('guard', event['timestamp'])
              fp.gain_absorb(event['ability']['guid'], event['absorb'], :self_absorb, event['hitPoints'], event['timestamp'])
            when 115307 # gain shuffle
              fp.gain_shuffle(event['timestamp'])
            when 115308 # gain elusive brew
              fp.gain_cooldown('eb', event['timestamp'])
            when 152173 # gain serenity
              fp.serenity = true
            when 122783 # gain diffuse magic
              fp.gain_cooldown('dm', event['timestamp'])
            when 122278 # gain dampen harm
              fp.gain_cooldown('dh', event['timestamp'])    
            when 115176 # gain zen meditation
              fp.gain_cooldown('zm', event['timestamp'])
            when 120954 # gain fortifying brew
              fp.gain_cooldown('fb', event['timestamp'])
            end
          when 'removebuff'
            case event['ability']['guid'] 
            when 115295 # drop guard
              fp.drop_cooldown('guard', event['timestamp'])
              fp.drop_absorb(event['ability']['guid'], event['absorb'], :self_absorb, event['hitPoints'], event['timestamp'])
            when 115307 # drop shuffle
              fp.drop_shuffle(event['timestamp'])
            when 115308 # drop elusive brew
              fp.drop_cooldown('eb', event['timestamp'])
            when 152173 # drop serenity
              fp.serenity = false
            when 122783 # drop diffuse magic
              fp.drop_cooldown('dm', event['timestamp'])
            when 122278 # drop dampen harm
              fp.drop_cooldown('dh', event['timestamp'])    
            when 115176 # drop zen meditation
              fp.drop_cooldown('zm', event['timestamp'])
            when 120954 # drop fortifying brew
              fp.drop_cooldown('fb', event['timestamp'])
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
         when 'applybuff', 'refreshbuff'
            if event['sourceID'] != event['targetID'] && event.has_key?('absorb') # external absorb
              fp.gain_absorb(event['ability']['guid'], event['absorb'], :external_absorb, event['hitPoints'], event['timestamp'])
            end
          when 'removebuff'
            if event['sourceID'] != event['targetID'] && event.has_key?('absorb') # external absorb
              fp.drop_absorb(event['ability']['guid'], event['absorb'], :external_absorb, event['hitPoints'], event['timestamp'])
            end
          when 'absorbed'
            if event['targetID'] == event['sourceID'] # self-absorb
              if event['ability']['guid'] == 115069 # stagger
                fp.stagger(event['timestamp'], event['amount'], event['extraAbility']['guid'])
              elsif event['ability']['guid'] == 115295 # guard
                fp.guard(event['extraAbility']['guid'], event['extraAbility']['name'], event['amount'], event['hitPoints'], event['timestamp'])
              else # just in case
                fp.self_absorb(event['extraAbility']['guid'], event['amount'], event['hitPoints'], event['timestamp'])
              end
            else # external absorb received
              fp.external_absorb(event['ability']['guid'], event['amount'], event['hitPoints'], event['timestamp'])
            end
          when 'heal'
            if event['targetID'] == event['sourceID'] # self-healing
              fp.self_heal(event['amount'], event['hitPoints'], event['timestamp'])
            else # external healing received
              fp.external_heal(event['amount'], event['hitPoints'], event['timestamp'])
            end
          when 'damage'
            fp.record_damage(event['timestamp'], event['sourceID'], event['sourceIsFriendly'], event['ability']['guid'], event['ability']['name'], event['ability']['type'], event['amount'], event['absorbed'], event['maxHitPoints'], event['tick'])
            if event['hitType'] == 7 # dodge
              fp.dodge(event['sourceID'], event['ability']['guid'], event['ability']['name'])
            end
            fp.record_hp(event['hitPoints'], event['timestamp'])
          end
        end
        cursor = event['timestamp'] + 1
      end
      if cursor >= fight.ended_at
        break
      else 
        response = HTTParty.get("https://www.warcraftlogs.com/v1/report/events/#{report_id}?start=#{cursor}&api_key=#{ENV['WCL_API_KEY']}")
        # puts '======='
        # puts "getting at time #{cursor}"
        obj = JSON.parse(response.body)
        events = obj['events']
      end
    end
    if bm_ids.count == 0
      fight.status = :empty
      fight.save
    else
      bm_ids.each do |bm_id, guid|
        fight_parses[bm_id].clean
        fight_parses[bm_id].save
      end
      fight.status = :done
      fight.save
    end

  rescue Resque::TermException
    Resque.enqueue(self, fight_id, report_id)
  end

end
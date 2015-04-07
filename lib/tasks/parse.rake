## hitTypes (probably)
# 1: normal
# 2: crit
# 3: absorbed
# 4: blocked
# 5: blocked crit
# 6: miss?
# 7: dodge
# 8: parry

namespace :log do
  task :parse => :environment do
    started_at = 1097549
    ended_at = 1385400

    fight_parses = {}
    bm_ids = {3 => 159857230}
    owners_by_pet_id = {}

    bm_ids.each do |bm_id, guid|
      FightParse.where(fight_id: 1, user_id: 'epwna', player_id: 1).destroy_all
      fight_parses[bm_id] = FightParse.create(fight_id: 1, user_id: 'epwna', player_id: 1)
      fight_parses[bm_id].started_at = started_at
      fight_parses[bm_id].ended_at = ended_at
    end

    (1..20).each do |i|
      log_file = File.join(Rails.root, 'lib', 'tasks', "log#{i}.json")
      log = JSON.parse(File.read(log_file))
      log['events'].each do |event|
        if bm_ids.has_key?(event['sourceID']) # the player did something
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
      end
    end

    bm_ids.each do |bm_id, guid|
      fight_parses[bm_id].clean
      fight_parses[bm_id].save
      fight_parses[bm_id].print
    end

  end
end

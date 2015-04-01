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
    fight_time = (ended_at - started_at) / 1000

    # init values
    kegsmash = tigerpalm = 0
    guarding = false
    guards = []
    current_guard = {absorbed: 0, healed: 0}

    ebing = false
    ebs = []
    current_eb = {}

    damage = {}

    # puts 'type, source, target, ability, guid, hitType, amount, notes, timestamp'
    (1..20).each do |i|
      log_file = File.join(Rails.root, 'lib', 'tasks', "log#{i}.json")
      log = JSON.parse(File.read(log_file))
      log['events'].each do |event|
        if event['sourceIsFriendly'] == true && event['sourceID'] == 3
          case event['type']
          when 'cast'
            kegsmash += 1 if event['ability']['guid'] == 121253
            tigerpalm += 1 if event['ability']['guid'] == 100787
          when 'applybuff'
            if event['ability']['guid'] == 115295 # gain guard
              guarding = true
              current_guard = {absorbed: 0, healed: 0}
            end
            if event['ability']['guid'] == 115308 # gain elusive brew
              ebing = true
              current_eb = {}
            end
          when 'removebuff'
            if event['ability']['guid'] == 115295 # drop guard
              guards << current_guard if guarding # can be messed up if guard was up when the fight began
              guarding = false
            end
            if event['ability']['guid'] == 115308 # drop elusive brew
              ebs << current_eb if ebing
              ebing = false
            end
          end
        end
        if event['targetIsFriendly'] == true && event['targetID'] == 3
          case event['type']
          when 'absorbed'
            if guarding
              current_guard[:absorbed] += event['amount']
            end
          when 'heal'
            if guarding && event['sourceIsFriendly'] == true && event['sourceID'] == 3
              current_guard[:healed] += event['amount']
            end
          when 'damage'
            unless [7,8].include? event['hitType'] # record damage from ability
              damage[event['sourceID']] = {} unless damage.has_key?(event['sourceID'])
              damage[event['sourceID']][event['ability']['guid']] = {name: event['ability']['name'], avg: 0.0, count: 0} unless damage[event['sourceID']].has_key?(event['ability']['guid'])
              damage[event['sourceID']][event['ability']['guid']][:avg] = damage[event['sourceID']][event['ability']['guid']][:avg] * damage[event['sourceID']][event['ability']['guid']][:count] / (damage[event['sourceID']][event['ability']['guid']][:count] + 1) + (event['amount'] + event['absorbed']) * 1 / (damage[event['sourceID']][event['ability']['guid']][:count] + 1)
              damage[event['sourceID']][event['ability']['guid']][:count] += 1
            end
            if ebing && event['hitType'] == 7 # dodge with elusive brew
              current_eb[event['sourceID']] = {} unless current_eb.has_key?(event['sourceID'])
              current_eb[event['sourceID']][event['ability']['guid']] = {name: event['ability']['name'], dodged: 0} unless current_eb[event['sourceID']].has_key?(event['ability']['guid'])
              current_eb[event['sourceID']][event['ability']['guid']][:dodged] += 1
            end
          end
        end

        # if event['multistrike']
        #   note = 'ms'
        # elsif [4,5].include? event['hitType']
        #   note = event['blocked']
        # else
        #   note = event['absorbed']
        # end
        # puts "#{event['type']}, #{event['sourceID']}, #{event['targetID']}, #{event['ability']['name']}, #{event['ability']['guid']}, #{event['hitType']}, #{event['amount'] || event['stack'] || event['resourceChange']}, #{note}, #{event['timestamp']}"
      end
    end
    puts "Kegsmash: #{kegsmash}/#{fight_time/8} (#{100*kegsmash/(fight_time/8)}%)"
    puts "Tigerpalm: #{tigerpalm}"
    puts ""
    total_guard = 0
    guards.each_with_index do |g, i|
      # puts g
      guarded = g[:absorbed] + (g[:healed]/1.3).to_i
      puts "Guard #{i+1}: Absorbed #{g[:absorbed]}, Healed #{g[:healed]} (#{guarded})"
      total_guard += guarded
    end
    puts "Total Guard: #{total_guard} (#{total_guard / fight_time} HPS)"
    puts ""
    total_eb = 0
    ebs.each_with_index do |eb, i|
      puts "Elusive Brew #{i+1}:"
      eb_dmg = 0
      eb.each do |source_id, source|
        source.each do |ability_id, ability|
          avoided_dmg = (damage[source_id][ability_id][:avg] * ability[:dodged]).to_i
          eb_dmg += avoided_dmg
          puts "#{ability[:name]}: dodged #{ability[:dodged]} (#{avoided_dmg})"
        end
      end
      puts "Total Avoided Damage: #{eb_dmg}"
      total_eb += eb_dmg
      puts ""
    end
    puts "Total Damage avoided through Elusive Brew: #{total_eb} (#{total_eb / fight_time} HPS)"
    puts ""
  end
end

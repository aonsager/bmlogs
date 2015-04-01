namespace :log do
  task :parse => :environment do

    puts 'type, source, target, ability, aid, hitType, amount, notes, timestamp'
    (1..4).each do |i|
      log_file = File.join(Rails.root, 'lib', 'tasks', "log#{i}.json")
      log = JSON.parse(File.read(log_file))
      log['events'].each do |event|
        next unless (event['sourceIsFriendly'] == true && event['sourceID'] == 3) || (event['targetIsFriendly'] == true && event['targetID'] == 3)
        if event['multistrike']
          note = 'ms'
        elsif [4,5].include? event['hitType']
          note = event['blocked']
        else
          note = event['absorbed']
        end
        puts "#{event['type']}, #{event['sourceID']}, #{event['targetID']}, #{event['ability']['name']}, #{event['ability']['guid']}, #{event['hitType']}, #{event['amount'] || event['stack'] || event['resourceChange']}, #{note}, #{event['timestamp']}"
      end
    end
  end
end

## hitTypes (probably)
# 1: normal
# 2: crit
# 3: absorbed
# 4: blocked
# 5: blocked crit
# 6: miss?
# 7: dodge
# 8: parry
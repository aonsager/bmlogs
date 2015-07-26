desc "This task is called by the Heroku scheduler add-on"
task :clear_stuck_tasks => :environment do
  kill_time = ENV['kill_time'] || 600
  Resque.workers.each {|w| w.unregister_worker if w.processing['run_at'] && Time.now - w.processing['run_at'].to_time > kill_time}
end
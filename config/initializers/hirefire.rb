HireFire::Resource.configure do |config|
  config.dyno(:worker) do
    HireFire::Macro::Resque.queue(:parse)
  end
end
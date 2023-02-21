namespace :webpacker do
  desc "DEPRECATED - Verifies if the Shakapacker config is present"
  task :verify_config do |task|
    prefix = task.name.split(/#|webpacker:/).first
    Rake::Task["#{prefix}shakapacker:verify_config"].invoke
  end
end

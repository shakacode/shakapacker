namespace :webpacker do
  desc "DEPRECATED - Install Shakapacker in this application"
  task :install do |task|
    puts Shakapacker::DEPRECATION_MESSAGE

    prefix = task.name.split(/#|webpacker:/).first
    Rake::Task["#{prefix}shakapacker:install"].invoke
  end
end

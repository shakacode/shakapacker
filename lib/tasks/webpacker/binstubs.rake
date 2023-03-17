namespace :webpacker do
  desc "DEPRECATED - Installs Shakapacker binstubs in this application"
  task :binstubs do |task|
    Shakapacker.puts_rake_deprecation_message(task.name)

    prefix = task.name.split(/#|webpacker:/).first
    Rake::Task["#{prefix}shakapacker:binstubs"].invoke
  end
end

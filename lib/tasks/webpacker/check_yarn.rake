namespace :webpacker do
  desc "DEPRECATED - Verifies if Yarn is installed"
  task :check_yarn do |task|
    Shakapacker.puts_rake_deprecation_message(task.name)

    prefix = task.name.split(/#|webpacker:/).first
    Rake::Task["#{prefix}shakapacker:check_manager"].invoke
  end
end

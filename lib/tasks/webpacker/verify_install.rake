namespace :webpacker do
  desc "DEPRECATED - Verifies if Shakapacker is installed"
  task :verify_install do |task|
    Shakapacker.puts_rake_deprecation_message(task.name)

    prefix = task.name.split(/#|webpacker:/).first
    Rake::Task["#{prefix}shakapacker:verify_install"].invoke
  end
end

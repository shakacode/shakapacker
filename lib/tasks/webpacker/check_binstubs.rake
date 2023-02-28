namespace :webpacker do
  desc "DEPRECATED - Verifies that bin/shakapacker is present"
  task :check_binstubs do |task|
    Shakapacker.puts_rake_deprecation_message(task.name)

    prefix = task.name.split(/#|webpacker:/).first
    Rake::Task["#{prefix}shakapacker:check_binstubs"].invoke
  end
end

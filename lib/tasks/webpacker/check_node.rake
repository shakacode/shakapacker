namespace :webpacker do
  desc "DEPRECATED - Verifies if Node.js is installed"
  task :check_node do |task|
    Shakapacker.puts_rake_deprecation_message(task.name)

    prefix = task.name.split(/#|webpacker:/).first
    Rake::Task["#{prefix}shakapacker:check_node"].invoke
  end
end

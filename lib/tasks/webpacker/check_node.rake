namespace :webpacker do
  desc "DEPRECATED - Verifies if Node.js is installed"
  task :check_node do |task|
    prefix = task.name.split(/#|webpacker:/).first
    Rake::Task["#{prefix}shakapacker:check_node"].invoke
  end
end

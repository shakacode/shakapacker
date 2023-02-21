namespace :webpacker do
  desc "DEPRECATED - Verifies if Yarn is installed"
  task :check_yarn do |task|
    prefix = task.name.split(/#|webpacker:/).first
    Rake::Task["#{prefix}shakapacker:check_yarn"].invoke
  end
end

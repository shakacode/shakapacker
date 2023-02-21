namespace :webpacker do
  desc "DEPRECATED - Installs Shakapacker binstubs in this application"
  task :binstubs do |task|
    prefix = task.name.split(/#|webpacker:/).first
    Rake::Task["#{prefix}shakapacker:binstubs"].invoke
  end
end

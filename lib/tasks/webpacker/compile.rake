namespace :webpacker do
  desc "DEPRECATED - Compile JavaScript packs using webpack for production with digests"
  task :compile do |task|
    prefix = task.name.split(/#|webpacker:/).first
    Rake::Task["#{prefix}shakapacker:compile"].invoke
  end
end

require "shakapacker/configuration"

namespace :webpacker do
  desc "DEPRECATED - Remove the webpack compiled output directory"
  task :clobber do |task|
    prefix = task.name.split(/#|webpacker:/).first
    Rake::Task["#{prefix}shakapacker:clobber"].invoke
  end
end

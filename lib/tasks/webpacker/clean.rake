$stdout.sync = true

require "shakapacker/configuration"

namespace :webpacker do
  desc "Remove old compiled webpacks"
  task :clean, [:keep, :age] => ["webpacker:verify_install", :environment] do |_, args|
    Webpacker.ensure_log_goes_to_stdout do
      Webpacker.clean(Integer(args.keep || 2), Integer(args.age || 3600))
    end
  end
end

if Webpacker.config.webpacker_precompile?
  # Run clean if the assets:clean is run
  if Rake::Task.task_defined?("assets:clean")
    Rake::Task["assets:clean"].enhance do
      Rake::Task["webpacker:clean"].invoke
    end
  else
    Rake::Task.define_task("assets:clean" => "webpacker:clean")
  end
end

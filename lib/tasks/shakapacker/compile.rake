$stdout.sync = true

def enhance_assets_precompile
  Rake::Task["assets:precompile"].enhance do |task|
    prefix = task.name.split(/#|assets:precompile/).first

    Rake::Task["#{prefix}shakapacker:compile"].invoke
  end
end

namespace :shakapacker do
  desc "Compile JavaScript packs using webpack for production with digests"
  task compile: ["shakapacker:verify_install", :environment] do
    Shakapacker.with_node_env(ENV.fetch("NODE_ENV", "production")) do
      Shakapacker.ensure_log_goes_to_stdout do
        if Shakapacker.compile
          # Successful compilation!
        else
          # Failed compilation
          exit!
        end
      end
    end
  end
end

if Shakapacker.config.shakapacker_precompile?
  if Rake::Task.task_defined?("assets:precompile")
    # Rails already adds `yarn install` after 5.2
    # https://github.com/shakacode/shakapacker/issues/237
    enhance_assets_precompile
  else
    # Only add `yarn install` if Rails was not doing it (precompile was not defined).
    # TODO: Remove this in Shakapacker 7.0
    Rake::Task.define_task("assets:precompile" => ["shakapacker:yarn_install", "shakapacker:compile"])
  end
end

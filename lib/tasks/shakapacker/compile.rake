$stdout.sync = true

def enhance_assets_precompile
  Rake::Task["assets:precompile"].enhance do |task|
    prefix = task.name.split(/#|assets:precompile/).first

    Rake::Task["#{prefix}webpacker:compile"].invoke
  end
end

namespace :webpacker do
  desc "Compile JavaScript packs using webpack for production with digests"
  task compile: ["webpacker:verify_install", :environment] do
    Webpacker.with_node_env(ENV.fetch("NODE_ENV", "production")) do
      Webpacker.ensure_log_goes_to_stdout do
        if Webpacker.compile
          # Successful compilation!
        else
          # Failed compilation
          exit!
        end
      end
    end
  end
end

if Webpacker.config.webpacker_precompile?
  if Rake::Task.task_defined?("assets:precompile")
    # Rails already adds `yarn install` after 5.2
    # https://github.com/shakacode/shakapacker/issues/237
    enhance_assets_precompile
  else
    # Only add `yarn install` if Rails was not doing it (precompile was not defined).
    # TODO: Remove this in Shakapacker 7.0
    Rake::Task.define_task("assets:precompile" => ["webpacker:yarn_install", "webpacker:compile"])
  end
end

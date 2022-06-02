$stdout.sync = true

def enhance_assets_precompile
  # yarn:install was added in Rails 5.1
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

        compiled_ok_or_precompile_enhancement_disabled = Webpacker.run_if_webpacker_precompile do
          Webpacker.compile
        end

        if compiled_ok_or_precompile_enhancement_disabled
          # Successful compilation or skipped!
        else
          # Failed compilation
          exit!
        end
      end
    end
  end
end

if Rake::Task.task_defined?("assets:precompile")
  enhance_assets_precompile
else
  Rake::Task.define_task("assets:precompile" => ["webpacker:compile"])
end

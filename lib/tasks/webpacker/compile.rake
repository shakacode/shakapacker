$stdout.sync = true

def yarn_install_available?
  rails_major = Rails::VERSION::MAJOR
  rails_minor = Rails::VERSION::MINOR

  rails_major > 5 || (rails_major == 5 && rails_minor >= 1)
end

def enhance_assets_precompile
  # yarn:install was added in Rails 5.1
  deps = yarn_install_available? ? [] : ["webpacker:yarn_install"]
  Rake::Task["assets:precompile"].enhance(deps) do |task|
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
    enhance_assets_precompile
  else
    Rake::Task.define_task("assets:precompile" => ["webpacker:yarn_install", "webpacker:compile"])
  end
end

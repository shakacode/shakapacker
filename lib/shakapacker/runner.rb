require_relative "utils/misc"
require_relative "utils/manager"

require "package_json"

module Shakapacker
  class Runner
    def self.run(argv)
      $stdout.sync = true
      ENV["NODE_ENV"] ||= (ENV["RAILS_ENV"] == "production") ? "production" : "development"
      new(argv).run
    end

    def initialize(argv)
      @argv = argv

      @app_path              = File.expand_path(".", Dir.pwd)
      @shakapacker_config    = ENV["SHAKAPACKER_CONFIG"] || File.join(@app_path, "config/shakapacker.yml")
      @webpack_config        = find_bundler_config

      Shakapacker::Utils::Manager.error_unless_package_manager_is_obvious!
    end

    def package_json
      @package_json ||= PackageJson.read(@app_path)
    end

    private
      def find_bundler_config
        bundler = get_bundler_type
        
        if bundler == "rspack"
          find_rspack_config_with_fallback
        else
          find_webpack_config
        end
      end

      def get_bundler_type
        # Load the shakapacker configuration to determine bundler type
        return "webpack" unless File.exist?(@shakapacker_config)
        
        require "yaml"
        config = YAML.load_file(@shakapacker_config)
        rails_env = ENV["RAILS_ENV"] || ENV["NODE_ENV"] || "development"
        env_config = config[rails_env] || config["production"] || {}
        
        env_config["bundler"] || config.dig("default", "bundler") || "webpack"
      rescue
        "webpack" # fallback to webpack on any error
      end

      def find_rspack_config_with_fallback
        # First try rspack-specific paths
        rspack_paths = %w[ts js].map do |ext|
          File.join(@app_path, "config/rspack/rspack.config.#{ext}")
        end
        
        rspack_path = rspack_paths.find { |f| File.exist?(f) }
        return rspack_path if rspack_path

        # Fallback to webpack config with deprecation warning
        webpack_paths = %w[ts js].map do |ext|
          File.join(@app_path, "config/webpack/webpack.config.#{ext}")
        end
        
        webpack_path = webpack_paths.find { |f| File.exist?(f) }
        if webpack_path
          $stderr.puts "⚠️  DEPRECATION WARNING: Using webpack config file for Rspack bundler."
          $stderr.puts "   Please create config/rspack/rspack.config.js and migrate your configuration."
          $stderr.puts "   Using: #{webpack_path}"
          return webpack_path
        end

        # No config found
        $stderr.puts "rspack config #{rspack_paths.last} not found, please run 'bundle exec rails shakapacker:install' to install Shakapacker with default configs or create the missing config file."
        exit!
      end

      def find_webpack_config
        possible_paths = %w[ts js].map do |ext|
          File.join(@app_path, "config/webpack/webpack.config.#{ext}")
        end
        path = possible_paths.find { |f| File.exist?(f) }
        unless path
          $stderr.puts "webpack config #{possible_paths.last} not found, please run 'bundle exec rails shakapacker:install' to install Shakapacker with default configs or add the missing config file for your custom environment."
          exit!
        end
        path
      end
  end
end

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
      @webpack_config        = find_webpack_config

      Shakapacker::Utils::Manager.error_unless_package_manager_is_obvious!
    end

    def package_json
      @package_json ||= PackageJson.read(@app_path)
    end

    private
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

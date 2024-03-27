require "shakapacker/utils/misc"
require "shakapacker/utils/manager"
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
      @webpack_config        = File.join(@app_path, "config/webpack/webpack.config.js")
      @shakapacker_config    = ENV["SHAKAPACKER_CONFIG"] || File.join(@app_path, "config/shakapacker.yml")

      unless File.exist?(@webpack_config)
        $stderr.puts "webpack config #{@webpack_config} not found, please run 'bundle exec rails shakapacker:install' to install Shakapacker with default configs or add the missing config file for your custom environment."
        exit!
      end

      Shakapacker::Utils::Manager.error_unless_package_manager_is_obvious!
    end

    def package_json
      @package_json ||= PackageJson.read(@app_path)
    end
  end
end

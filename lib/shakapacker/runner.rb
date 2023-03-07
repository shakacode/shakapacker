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
      @node_modules_bin_path = ENV["SHAKAPACKER_NODE_MODULES_BIN_PATH"] || `yarn bin`.chomp
      @webpack_config        = File.join(@app_path, "config/webpack/webpack.config.js")
      @webpacker_config      = ENV["SHAKAPACKER_CONFIG"] || File.join(@app_path, "config/shakapacker.yml")

      unless File.exist?(@webpack_config)
        $stderr.puts "webpack config #{@webpack_config} not found, please run 'bundle exec rails webpacker:install' to install Webpacker with default configs or add the missing config file for your custom environment."
        exit!
      end
    end
  end
end

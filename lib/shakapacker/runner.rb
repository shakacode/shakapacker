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

      Shakapacker.set_shakapacker_env_variables_for_backward_compatibility

      @node_modules_bin_path = ENV["SHAKAPACKER_NODE_MODULES_BIN_PATH"] || `yarn bin`.chomp
      @shakapacker_config    = ENV["SHAKAPACKER_CONFIG"] || File.join(@app_path, "config/shakapacker.yml")

      @shakapacker_config = Shakapacker.get_config_file_path_with_backward_compatibility(@shakapacker_config)

      unless File.exist?(@webpack_config)
        $stderr.puts "webpack config #{@webpack_config} not found, please run 'bundle exec rails shakapacker:install' to install Shakapacker with default configs or add the missing config file for your custom environment."
        exit!
      end
    end
  end
end

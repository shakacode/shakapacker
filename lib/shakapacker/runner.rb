require_relative "utils/misc"
require_relative "utils/manager"
require_relative "configuration"

require "package_json"
require "pathname"

module Shakapacker
  class Runner
    # Common commands that don't work with --config option
    BASE_COMMANDS = [
      "help",
      "h",
      "--help",
      "-h",
      "version",
      "v",
      "--version",
      "-v",
      "info",
      "i"
    ].freeze
    def self.run(argv)
      $stdout.sync = true
      ENV["NODE_ENV"] ||= (ENV["RAILS_ENV"] == "production") ? "production" : "development"

      # Determine which runner to use based on configuration
      runner = new(argv)
      config = runner.instance_variable_get(:@config)

      if config.rspack?
        require_relative "rspack_runner"
        RspackRunner.new(argv).run
      else
        require_relative "webpack_runner"
        WebpackRunner.new(argv).run
      end
    end

    def initialize(argv)
      @argv = argv

      @app_path              = File.expand_path(".", Dir.pwd)
      @shakapacker_config    = ENV["SHAKAPACKER_CONFIG"] || File.join(@app_path, "config/shakapacker.yml")
      @config                = Configuration.new(
        root_path: Pathname.new(@app_path),
        config_path: Pathname.new(@shakapacker_config),
        env: ENV["RAILS_ENV"] || ENV["NODE_ENV"] || "development"
      )
      @webpack_config        = find_bundler_config

      Shakapacker::Utils::Manager.error_unless_package_manager_is_obvious!
    end

    def package_json
      @package_json ||= PackageJson.read(@app_path)
    end

    def run
      env = Shakapacker::Compiler.env
      env["SHAKAPACKER_CONFIG"] = @shakapacker_config
      env["NODE_OPTIONS"] = ENV["NODE_OPTIONS"] || ""

      cmd = build_cmd

      if @argv.delete("--debug-shakapacker")
        env["NODE_OPTIONS"] = "#{env["NODE_OPTIONS"]} --inspect-brk"
      end

      if @argv.delete "--trace-deprecation"
        env["NODE_OPTIONS"] = "#{env["NODE_OPTIONS"]} --trace-deprecation"
      end

      if @argv.delete "--no-deprecation"
        env["NODE_OPTIONS"] = "#{env["NODE_OPTIONS"]} --no-deprecation"
      end

      # Commands are not compatible with --config option.
      if (@argv & bundler_commands).empty?
        cmd += ["--config", @webpack_config]
      end

      cmd += @argv

      Dir.chdir(@app_path) do
        Kernel.exec env, *cmd
      end
    end

    protected

      def bundler_commands
        BASE_COMMANDS
      end

    private
      def find_bundler_config
        if @config.rspack?
          find_rspack_config_with_fallback
        else
          find_webpack_config
        end
      end

      def get_bundler_type
        @config.bundler
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
        exit(1)
      end

      def find_webpack_config
        possible_paths = %w[ts js].map do |ext|
          File.join(@app_path, "config/webpack/webpack.config.#{ext}")
        end
        path = possible_paths.find { |f| File.exist?(f) }
        unless path
          $stderr.puts "webpack config #{possible_paths.last} not found, please run 'bundle exec rails shakapacker:install' to install Shakapacker with default configs or add the missing config file for your custom environment."
          exit(1)
        end
        path
      end
  end
end

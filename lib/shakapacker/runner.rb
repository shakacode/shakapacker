require_relative "utils/misc"
require_relative "utils/manager"
require_relative "configuration"
require_relative "version"

require "package_json"
require "pathname"

module Shakapacker
  class Runner
    attr_reader :config

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

      # Show Shakapacker help before webpack/rspack help
      if argv.include?("--help") || argv.include?("-h")
        print_help
        puts "\n" + "=" * 80
        puts "WEBPACK/RSPACK OPTIONS"
        puts "=" * 80
        puts "The following options are passed through to webpack/rspack:\n\n"
        # Continue to show bundler help by not exiting
      end

      # Handle version flags - show both Shakapacker and bundler versions
      if argv.include?("--version") || argv.include?("-v")
        print_version
        puts "\nBundler version:"
        # Continue to show bundler version by not exiting
      end

      Shakapacker.ensure_node_env!

      # Create a single runner instance to avoid loading configuration twice.
      # We extend it with the appropriate build command based on the bundler type.
      runner = new(argv)

      if runner.config.rspack?
        require_relative "rspack_runner"
        # Extend the runner instance with rspack-specific methods
        # This avoids creating a new RspackRunner which would reload the configuration
        runner.extend(Module.new do
          def build_cmd
            package_json.manager.native_exec_command("rspack")
          end

          def assets_bundler_commands
            BASE_COMMANDS + %w[build watch]
          end
        end)
        runner.run
      else
        require_relative "webpack_runner"
        # Extend the runner instance with webpack-specific methods
        # This avoids creating a new WebpackRunner which would reload the configuration
        runner.extend(Module.new do
          def build_cmd
            package_json.manager.native_exec_command("webpack")
          end
        end)
        runner.run
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
      @webpack_config        = find_assets_bundler_config

      Shakapacker::Utils::Manager.error_unless_package_manager_is_obvious!
    end

    def package_json
      @package_json ||= PackageJson.read(@app_path)
    end

    def run
      puts "[Shakapacker] Preparing environment for assets bundler execution..."
      env = Shakapacker::Compiler.env
      env["SHAKAPACKER_CONFIG"] = @shakapacker_config
      env["NODE_OPTIONS"] = ENV["NODE_OPTIONS"] || ""

      cmd = build_cmd
      puts "[Shakapacker] Base command: #{cmd.join(" ")}"

      if @argv.delete("--debug-shakapacker")
        puts "[Shakapacker] Debug mode enabled (--debug-shakapacker)"
        env["NODE_OPTIONS"] = "#{env["NODE_OPTIONS"]} --inspect-brk"
      end

      if @argv.delete "--trace-deprecation"
        puts "[Shakapacker] Trace deprecation enabled (--trace-deprecation)"
        env["NODE_OPTIONS"] = "#{env["NODE_OPTIONS"]} --trace-deprecation"
      end

      if @argv.delete "--no-deprecation"
        puts "[Shakapacker] Deprecation warnings disabled (--no-deprecation)"
        env["NODE_OPTIONS"] = "#{env["NODE_OPTIONS"]} --no-deprecation"
      end

      # Commands are not compatible with --config option.
      if (@argv & assets_bundler_commands).empty?
        puts "[Shakapacker] Adding config file: #{@webpack_config}"
        cmd += ["--config", @webpack_config]
      else
        puts "[Shakapacker] Skipping config file (running assets bundler command: #{(@argv & assets_bundler_commands).join(", ")})"
      end

      cmd += @argv
      puts "[Shakapacker] Final command: #{cmd.join(" ")}"
      puts "[Shakapacker] Working directory: #{@app_path}"

      Dir.chdir(@app_path) do
        Kernel.exec env, *cmd
      end
    end

    protected

      def assets_bundler_commands
        BASE_COMMANDS
      end

      def self.print_help
        puts <<~HELP
        ================================================================================
        SHAKAPACKER - Rails Webpack/Rspack Integration
        ================================================================================

        Usage: bin/shakapacker [options]

        Shakapacker-specific options:
          --debug-shakapacker       Enable Node.js debugging (--inspect-brk)
          --trace-deprecation       Show stack traces for deprecations
          --no-deprecation          Silence deprecation warnings

        Examples:
          bin/shakapacker                    # Build for production
          bin/shakapacker --mode development # Build for development
          bin/shakapacker --watch            # Watch mode
          bin/shakapacker --debug-shakapacker # Debug with Node inspector

        All other options (--mode, --watch, --config, etc.) are passed through
        to webpack or rspack. See their documentation for details:
          Webpack: https://webpack.js.org/api/cli/
          Rspack:  https://rspack.dev/api/cli
      HELP
      end

      def self.print_version
        puts "Shakapacker #{Shakapacker::VERSION}"
        puts "Framework: Rails #{defined?(Rails) ? Rails.version : "N/A"}"
      end

    private
      def find_assets_bundler_config
        if @config.rspack?
          find_rspack_config_with_fallback
        else
          find_webpack_config
        end
      end

      def find_rspack_config_with_fallback
        # First try rspack-specific paths
        rspack_paths = %w[ts js].map do |ext|
          File.join(@app_path, "config/rspack/rspack.config.#{ext}")
        end

        puts "[Shakapacker] Looking for Rspack config in: #{rspack_paths.join(", ")}"
        rspack_path = rspack_paths.find { |f| File.exist?(f) }
        if rspack_path
          puts "[Shakapacker] Found Rspack config: #{rspack_path}"
          return rspack_path
        end

        # Fallback to webpack config with deprecation warning
        webpack_paths = %w[ts js].map do |ext|
          File.join(@app_path, "config/webpack/webpack.config.#{ext}")
        end

        puts "[Shakapacker] Rspack config not found, checking for webpack config fallback..."
        webpack_path = webpack_paths.find { |f| File.exist?(f) }
        if webpack_path
          $stderr.puts "⚠️  DEPRECATION WARNING: Using webpack config file for Rspack assets bundler."
          $stderr.puts "   Please create config/rspack/rspack.config.js and migrate your configuration."
          $stderr.puts "   Using: #{webpack_path}"
          return webpack_path
        end

        # No config found
        $stderr.puts "[Shakapacker] ERROR: rspack config #{rspack_paths.last} not found, please run 'bundle exec rails shakapacker:install' to install Shakapacker with default configs or create the missing config file."
        exit(1)
      end

      def find_webpack_config
        possible_paths = %w[ts js].map do |ext|
          File.join(@app_path, "config/webpack/webpack.config.#{ext}")
        end
        puts "[Shakapacker] Looking for Webpack config in: #{possible_paths.join(", ")}"
        path = possible_paths.find { |f| File.exist?(f) }
        unless path
          $stderr.puts "[Shakapacker] ERROR: webpack config #{possible_paths.last} not found, please run 'bundle exec rails shakapacker:install' to install Shakapacker with default configs or add the missing config file for your custom environment."
          exit(1)
        end
        puts "[Shakapacker] Found Webpack config: #{path}"
        path
      end
  end
end

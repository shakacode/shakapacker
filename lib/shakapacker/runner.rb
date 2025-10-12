require_relative "utils/misc"
require_relative "utils/manager"
require_relative "configuration"
require_relative "version"

require "package_json"
require "pathname"
require "stringio"

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

      # Show Shakapacker help and exit (don't call bundler)
      if argv.include?("--help") || argv.include?("-h")
        print_help
        exit(0)
      elsif argv.include?("--version") || argv.include?("-v")
        print_version
        exit(0)
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

        Options managed by Shakapacker (configured via config files):
          --config                  Set automatically to config/webpack/webpack.config.js
                                    or config/rspack/rspack.config.js
          --node-env                Set from RAILS_ENV or NODE_ENV

        Examples:
          bin/shakapacker                              # Build for production
          bin/shakapacker --mode development           # Build for development
          bin/shakapacker --watch                      # Watch mode
          bin/shakapacker --mode development --analyze # Development build with analysis
          bin/shakapacker --debug-shakapacker          # Debug with Node inspector

        HELP

        print_bundler_help
      end

      def self.print_bundler_help
        bundler_type, bundler_help = get_bundler_help

        if bundler_help
          bundler_name = bundler_type == :rspack ? "RSPACK" : "WEBPACK"
          puts "=" * 80
          puts "AVAILABLE #{bundler_name} OPTIONS"
          puts "=" * 80
          puts
          puts filter_managed_options(bundler_help)
          puts
          puts "For complete documentation:"
          if bundler_type == :rspack
            puts "  https://rspack.dev/api/cli"
          else
            puts "  https://webpack.js.org/api/cli/"
          end
        else
          puts "For complete documentation:"
          puts "  Webpack: https://webpack.js.org/api/cli/"
          puts "  Rspack:  https://rspack.dev/api/cli"
        end
      end

      def self.get_bundler_help
        # Check if we're in a Rails project with necessary files
        app_path = File.expand_path(".", Dir.pwd)
        config_path = ENV["SHAKAPACKER_CONFIG"] || File.join(app_path, "config/shakapacker.yml")
        return [nil, nil] unless File.exist?(config_path)

        # Suppress any output during config loading
        original_stdout = $stdout
        original_stderr = $stderr
        $stdout = StringIO.new
        $stderr = StringIO.new

        # Try to detect bundler and get help
        runner = new([])
        return [nil, nil] unless runner.config

        bundler_type = runner.config.rspack? ? :rspack : :webpack
        cmd = if bundler_type == :rspack
                runner.package_json.manager.native_exec_command("rspack", ["--help"])
              else
                runner.package_json.manager.native_exec_command("webpack", ["--help"])
              end

        # Restore output before running command
        $stdout = original_stdout
        $stderr = original_stderr

        # Capture help output
        require "open3"
        stdout, _stderr, status = Open3.capture3(*cmd)
        [bundler_type, (status.success? ? stdout : nil)]
      rescue StandardError => e
        # Restore output if error occurs
        $stdout = original_stdout if $stdout != original_stdout
        $stderr = original_stderr if $stderr != original_stderr
        [nil, nil]
      end

      def self.filter_managed_options(help_text)
        # Remove options that Shakapacker manages and command sections
        lines = help_text.lines
        filtered_lines = []
        skip_until_blank = false
        in_commands_section = false

        lines.each do |line|
          # Skip the [options] line and Commands section
          if line.match?(/^\[options\]/) || line.match?(/^Commands:/)
            in_commands_section = true
            next
          end

          # Skip until we hit Options: section or blank line after commands
          if in_commands_section
            if line.match?(/^Options:/) || (line.strip.empty? && filtered_lines.last&.strip&.empty?)
              in_commands_section = false
            else
              next
            end
          end

          # Skip config-related options
          if line.match?(/^\s*(-c,\s*)?--config\b/) ||
             line.match?(/^\s*--configName\b/) ||
             line.match?(/^\s*--configLoader\b/) ||
             line.match?(/^\s*--nodeEnv\b/)
            skip_until_blank = true
            next
          end

          # Reset skip flag on blank line or new option
          if skip_until_blank
            if line.strip.empty? || line.match?(/^\s*-/)
              skip_until_blank = false
            else
              next
            end
          end

          filtered_lines << line
        end

        filtered_lines.join
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

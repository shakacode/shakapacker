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
          -h, --help                Show this help message
          -v, --version             Show Shakapacker version
          --debug-shakapacker       Enable Node.js debugging (--inspect-brk)
          --trace-deprecation       Show stack traces for deprecations
          --no-deprecation          Silence deprecation warnings

        Examples:
          bin/shakapacker                              # Build for production
          bin/shakapacker --mode development           # Build for development
          bin/shakapacker --watch                      # Watch mode
          bin/shakapacker --mode development --analyze # Development build with analysis
          bin/shakapacker --debug-shakapacker          # Debug with Node inspector

        HELP

        print_bundler_help

        puts <<~HELP

        Options managed by Shakapacker (configured via config files):
          --config                  Set automatically based on assets_bundler_config_path
                                    (defaults to config/webpack or config/rspack)
          --node-env                Set from RAILS_ENV or NODE_ENV
        HELP
      end

      def self.print_bundler_help
        bundler_type, bundler_help = get_bundler_help

        if bundler_help
          bundler_name = bundler_type == :rspack ? "RSPACK" : "WEBPACK"
          puts "=" * 80
          puts "AVAILABLE #{bundler_name} OPTIONS (Passed directly to #{bundler_name.downcase})"
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
        execute_bundler_command("--help") { |stdout| stdout }
      end

      # Filter bundler help output to remove Shakapacker-managed options
      #
      # This method processes the raw help output from webpack/rspack and removes:
      # 1. Command sections (e.g., "Commands: webpack build")
      # 2. Options that Shakapacker manages automatically (--config, --nodeEnv, etc.)
      # 3. Help/version flags (shown separately in Shakapacker's help)
      #
      # The filtering uses stateful line-by-line processing:
      # - in_commands_section: tracks when we're inside a Commands: block
      # - skip_until_blank: tracks multi-line option descriptions to skip entirely
      #
      # Note: This relies on bundler help format conventions. If webpack/rspack
      # significantly changes their help output format, this may need adjustment.
      def self.filter_managed_options(help_text)
        lines = help_text.lines
        filtered_lines = []
        skip_until_blank = false
        in_commands_section = false

        lines.each do |line|
          # Skip the [options] line and Commands section headers
          # These appear in formats like "[options]" or "Commands:"
          if line.match?(/^\[options\]/) || line.match?(/^Commands:/)
            in_commands_section = true
            next
          end

          # Continue skipping until we exit the commands section
          # Exit when we hit "Options:" header or double blank lines
          if in_commands_section
            if line.match?(/^Options:/) || (line.strip.empty? && filtered_lines.last&.strip&.empty?)
              in_commands_section = false
            else
              next
            end
          end

          # Skip options that Shakapacker manages and their descriptions
          # These options are shown in the "Options managed by Shakapacker" section
          if line.match?(/^\s*(-c,\s*)?--config\b/) ||
             line.match?(/^\s*--configName\b/) ||
             line.match?(/^\s*--configLoader\b/) ||
             line.match?(/^\s*--nodeEnv\b/) ||
             line.match?(/^\s*(-h,\s*)?--help\b/) ||
             line.match?(/^\s*(-v,\s*)?--version\b/)
            skip_until_blank = true
            next
          end

          # Continue skipping lines that are part of a filtered option's description
          # Reset when we hit a blank line or the start of a new option (starts with -)
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
        puts "Framework: Rails #{Rails.version}" if defined?(Rails)

        # Try to get bundler version
        bundler_type, bundler_version = get_bundler_version
        if bundler_version
          bundler_name = bundler_type == :rspack ? "Rspack" : "Webpack"
          puts "Bundler: #{bundler_name} #{bundler_version}"
        end
      end

      def self.get_bundler_version
        execute_bundler_command("--version") { |stdout| stdout.strip }
      end

      # Shared helper to execute bundler commands with output suppression
      # Returns [bundler_type, processed_output] or [nil, nil] on error
      #
      # @param bundler_args [String, Array<String>] Arguments to pass to bundler command
      # @yield [stdout] Block to process the command output
      # @yieldparam stdout [String] The raw stdout from the bundler command
      # @yieldreturn [Object] The processed output to return
      def self.execute_bundler_command(*bundler_args)
        # Check if we're in a Rails project with necessary files
        app_path = File.expand_path(".", Dir.pwd)
        config_path = ENV["SHAKAPACKER_CONFIG"] || File.join(app_path, "config/shakapacker.yml")
        return [nil, nil] unless File.exist?(config_path)

        original_stdout = $stdout
        original_stderr = $stderr

        begin
          # Suppress any output during config loading
          $stdout = StringIO.new
          $stderr = StringIO.new

          # Try to detect bundler type
          runner = new([])
          return [nil, nil] unless runner.config

          bundler_type = runner.config.rspack? ? :rspack : :webpack
          bundler_name = bundler_type == :rspack ? "rspack" : "webpack"
          cmd = runner.package_json.manager.native_exec_command(bundler_name, bundler_args.flatten)

          # Restore output before running command
          $stdout = original_stdout
          $stderr = original_stderr

          # Capture command output
          require "open3"
          stdout, _stderr, status = Open3.capture3(*cmd)
          return [nil, nil] unless status.success?

          # Process output using the provided block
          processed_output = yield(stdout)
          [bundler_type, processed_output]
        rescue StandardError => e
          [nil, nil]
        ensure
          # Always restore output streams
          $stdout = original_stdout
          $stderr = original_stderr
        end
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
        config_dir = @config.assets_bundler_config_path

        # First try rspack-specific paths in the configured directory
        rspack_paths = %w[ts js].map do |ext|
          File.join(@app_path, config_dir, "rspack.config.#{ext}")
        end

        puts "[Shakapacker] Looking for Rspack config in: #{rspack_paths.join(", ")}"
        rspack_path = rspack_paths.find { |f| File.exist?(f) }
        if rspack_path
          puts "[Shakapacker] Found Rspack config: #{rspack_path}"
          return rspack_path
        end

        # Fallback to webpack config with deprecation warning
        webpack_paths = %w[ts js].map do |ext|
          File.join(@app_path, config_dir, "webpack.config.#{ext}")
        end

        puts "[Shakapacker] Rspack config not found, checking for webpack config fallback..."
        webpack_path = webpack_paths.find { |f| File.exist?(f) }
        if webpack_path
          $stderr.puts "⚠️  DEPRECATION WARNING: Using webpack config file for Rspack assets bundler."
          $stderr.puts "   Please create #{config_dir}/rspack.config.js and migrate your configuration."
          $stderr.puts "   Using: #{webpack_path}"
          return webpack_path
        end

        # No config found
        $stderr.puts "[Shakapacker] ERROR: rspack config #{rspack_paths.last} not found, please run 'bundle exec rails shakapacker:install' to install Shakapacker with default configs or create the missing config file."
        exit(1)
      end

      def find_webpack_config
        config_dir = @config.assets_bundler_config_path

        possible_paths = %w[ts js].map do |ext|
          File.join(@app_path, config_dir, "webpack.config.#{ext}")
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

require "shellwords"
require "socket"

require_relative "configuration"
require_relative "dev_server"
require_relative "runner"
require_relative "version"

module Shakapacker
  class DevServerRunner < Shakapacker::Runner
    def self.run(argv)
      # Show Shakapacker help and exit (don't call bundler)
      if argv.include?("--help") || argv.include?("-h")
        print_help
        exit(0)
      elsif argv.include?("--version") || argv.include?("-v")
        print_version
        exit(0)
      end

      # Check if first argument is a build name from .bundler-config.yml
      if argv.length > 0 && !argv[0].start_with?("-")
        potential_build_name = argv[0]
        loader = BuildConfigLoader.new

        if loader.exists?
          begin
            build_config = loader.resolve_build_config(potential_build_name)

            # Run with this build config
            run_with_build_config(argv[1..-1] || [], build_config)
            return
          rescue ArgumentError => e
            # If build name not found, treat as regular argv
            if e.message.include?("Build '#{potential_build_name}' not found")
              # Continue to normal flow
            else
              # Re-raise other errors (like missing config file)
              $stderr.puts "[Shakapacker] #{e.message}"
              exit(1)
            end
          end
        end
      end

      new(argv).run
    end

    def self.run_with_build_config(argv, build_config)
      # Apply build config environment variables
      build_config[:environment].each do |key, value|
        ENV[key] = value.to_s
      end

      puts "[Shakapacker] Running dev server for build: #{build_config[:name]}"
      puts "[Shakapacker] Description: #{build_config[:description]}" if build_config[:description]
      puts "[Shakapacker] Bundler: #{build_config[:bundler]}"

      new(argv, build_config).run
    end

    def self.print_help
      puts <<~HELP
        ================================================================================
        SHAKAPACKER DEV SERVER - Development Server with Hot Module Replacement
        ================================================================================

        Usage: bin/shakapacker-dev-server [build-name] [options]

        Shakapacker-specific options:
          -h, --help              Show this help message
          -v, --version           Show Shakapacker version
          --debug-shakapacker     Enable Node.js debugging (--inspect-brk)

        Build configurations (.bundler-config.yml):
          If you have a .bundler-config.yml file, you can run predefined builds:

          bin/shakapacker-dev-server dev-hmr            # Run the 'dev-hmr' build

          To see available builds:
          bin/export-bundler-config --list-builds

          To create a config file:
          bin/export-bundler-config --init

          Note: You can also use bin/shakapacker with a build name that has
          WEBPACK_SERVE=true, and it will automatically use the dev server.

        Examples:
          bin/shakapacker-dev-server                    # Start dev server
          bin/shakapacker-dev-server --no-hot           # Disable HMR
          bin/shakapacker-dev-server --open             # Open browser automatically
          bin/shakapacker-dev-server --debug-shakapacker # Debug with Node inspector

      HELP

      print_dev_server_help

      puts <<~HELP

        Options managed by Shakapacker (configured in config/shakapacker.yml):
          --host                  Set from dev_server.host (default: localhost)
          --port                  Set from dev_server.port (default: 3035)
          --https                 Set from dev_server.server (http or https)
          --config                Set automatically to config/webpack/webpack.config.js
                                  or config/rspack/rspack.config.js

        Note: CLI flags for --host, --port, and --https are NOT supported.
        Configure these in config/shakapacker.yml instead.
      HELP
    end

    def self.print_dev_server_help
      bundler_type, bundler_help = get_dev_server_help

      if bundler_help
        bundler_name = bundler_type == :rspack ? "RSPACK" : "WEBPACK"
        puts "=" * 80
        puts "AVAILABLE #{bundler_name} DEV SERVER OPTIONS (Passed directly to #{bundler_name.downcase})"
        puts "=" * 80
        puts
        puts filter_managed_options(bundler_help)
        puts
        puts "For complete documentation:"
        if bundler_type == :rspack
          puts "  https://rspack.dev/config/dev-server"
        else
          puts "  https://webpack.js.org/configuration/dev-server/"
        end
      else
        puts "For complete documentation:"
        puts "  Webpack: https://webpack.js.org/configuration/dev-server/"
        puts "  Rspack:  https://rspack.dev/config/dev-server"
      end
    end

    def self.get_dev_server_help
      Runner.execute_bundler_command("serve", "--help") { |stdout| stdout }
    end

    # Filter dev server help output to remove Shakapacker-managed options
    #
    # This method processes the raw help output from webpack-dev-server/rspack serve
    # and removes options that Shakapacker manages automatically:
    # - --config (set from config/webpack or config/rspack)
    # - --host, --port (set from config/shakapacker.yml dev_server settings)
    # - --help, --version (shown separately in Shakapacker's help)
    #
    # The filtering uses skip_until_blank to track multi-line option descriptions
    # and skip them entirely when the option header matches a managed option.
    #
    # Note: This relies on dev server help format conventions. If webpack-dev-server
    # or rspack significantly changes their help output format, this may need adjustment.
    def self.filter_managed_options(help_text)
      lines = help_text.lines
      filtered_lines = []
      skip_until_blank = false

      lines.each do |line|
        # Skip options that Shakapacker manages and their descriptions
        # These options are shown in the "Options managed by Shakapacker" section
        if line.match?(/^\s*(-c,\s*)?--config\b/) ||
           line.match?(/^\s*--configName\b/) ||
           line.match?(/^\s*--configLoader\b/) ||
           line.match?(/^\s*--nodeEnv\b/) ||
           line.match?(/^\s*--host\b/) ||
           line.match?(/^\s*--port\b/) ||
           line.match?(/^\s*--https\b/) ||
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
      bundler_type, bundler_version = Runner.get_bundler_version
      if bundler_version
        bundler_name = bundler_type == :rspack ? "Rspack" : "Webpack"
        puts "Bundler: #{bundler_name} #{bundler_version}"
      end
    end

    def run
      load_config
      detect_unsupported_switches!
      detect_port!
      execute_cmd
    end

    private

      def load_config
        app_root = Pathname.new(@app_path)

        @config = Configuration.new(
          root_path: app_root,
          config_path: Pathname.new(@shakapacker_config),
          env: ENV["RAILS_ENV"]
        )

        dev_server = DevServer.new(@config)

        @hostname          = dev_server.host
        @port              = dev_server.port
        @pretty            = dev_server.pretty?
        @https             = dev_server.protocol == "https"
        @hot               = dev_server.hmr?

      rescue Errno::ENOENT, NoMethodError
        $stdout.puts "webpack 'dev_server' configuration not found in #{@config.config_path}[#{ENV["RAILS_ENV"]}]."
        $stdout.puts "Please run bundle exec rails shakapacker:install to install Shakapacker"
        exit!
      end

      UNSUPPORTED_SWITCHES = %w[--host --port]
      private_constant :UNSUPPORTED_SWITCHES
      def detect_unsupported_switches!
        unsupported_switches = UNSUPPORTED_SWITCHES & @argv
        if unsupported_switches.any?
          $stdout.puts "The following CLI switches are not supported by Shakapacker: #{unsupported_switches.join(' ')}. Please edit your command and try again."
          exit!
        end

        if @argv.include?("--https") && !@https
          $stdout.puts "--https requires that 'server' in shakapacker.yml is set to 'https'"
          exit!
        end
      end

      def detect_port!
        server = TCPServer.new(@hostname, @port)
        server.close

      rescue Errno::EADDRINUSE
        $stdout.puts "Another program is running on port #{@port}. Set a new port in #{@config.config_path} for dev_server"
        exit!
      end

      def execute_cmd
        env = Shakapacker::Compiler.env
        env["SHAKAPACKER_CONFIG"] = @shakapacker_config
        env["WEBPACK_SERVE"] = "true"
        env["NODE_OPTIONS"] = ENV["NODE_OPTIONS"] || ""

        cmd = build_cmd

        if @argv.delete("--debug-shakapacker")
          env["NODE_OPTIONS"] = "#{env["NODE_OPTIONS"]} --inspect-brk --trace-warnings"
        end

        # Add config file
        cmd += ["--config", @webpack_config]

        # Add assets bundler-specific flags
        if webpack?
          cmd += ["--progress", "--color"] if @pretty
          # Default behavior of webpack-dev-server is @hot = true
          cmd += ["--hot", "only"] if @hot == "only"
          cmd += ["--no-hot"] if !@hot
        elsif rspack?
          # Rspack supports --hot but not --no-hot or --progress/--color
          cmd += ["--hot"] if @hot && @hot != false
        end

        cmd += @argv

        Dir.chdir(@app_path) do
          system(env, *cmd)
        end

        exit($?.exitstatus || 1) unless $?.success?
      end

      def build_cmd
        command = @config.rspack? ? "rspack" : "webpack"
        package_json.manager.native_exec_command(command, ["serve"])
      end

      def webpack?
        @config.webpack?
      end

      def rspack?
        @config.rspack?
      end
  end
end

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

      new(argv).run
    end

    def self.print_help
      puts <<~HELP
        ================================================================================
        SHAKAPACKER DEV SERVER - Development Server with Hot Module Replacement
        ================================================================================

        Usage: bin/shakapacker-dev-server [options]

        Shakapacker-specific options:
          --debug-shakapacker     Enable Node.js debugging (--inspect-brk)

        Options managed by Shakapacker (configured in config/shakapacker.yml):
          --host                  Set from dev_server.host (default: localhost)
          --port                  Set from dev_server.port (default: 3035)
          --https                 Set from dev_server.server (http or https)
          --config                Set automatically to config/webpack/webpack.config.js
                                  or config/rspack/rspack.config.js

        Configuration:
          Host, port, and HTTPS are set in config/shakapacker.yml under 'dev_server'.
          CLI flags for these options are NOT supported - use the config file.

        Examples:
          bin/shakapacker-dev-server                    # Start dev server
          bin/shakapacker-dev-server --no-hot           # Disable HMR
          bin/shakapacker-dev-server --open             # Open browser automatically
          bin/shakapacker-dev-server --debug-shakapacker # Debug with Node inspector

      HELP

      print_dev_server_help
    end

    def self.print_dev_server_help
      bundler_help = get_dev_server_help

      if bundler_help
        puts "=" * 80
        puts "AVAILABLE DEV SERVER OPTIONS"
        puts "=" * 80
        puts
        puts filter_managed_options(bundler_help)
        puts
      end

      puts "For complete documentation:"
      puts "  Webpack: https://webpack.js.org/configuration/dev-server/"
      puts "  Rspack:  https://rspack.dev/config/dev-server"
    end

    def self.get_dev_server_help
      # Check if we're in a Rails project with necessary files
      app_path = File.expand_path(".", Dir.pwd)
      config_path = ENV["SHAKAPACKER_CONFIG"] || File.join(app_path, "config/shakapacker.yml")
      return nil unless File.exist?(config_path)

      # Suppress any output during config loading
      original_stdout = $stdout
      original_stderr = $stderr
      $stdout = StringIO.new
      $stderr = StringIO.new

      # Try to get dev server help
      runner = new([])
      return nil unless runner.config

      cmd = if runner.config.rspack?
              runner.package_json.manager.native_exec_command("rspack", ["serve", "--help"])
            else
              runner.package_json.manager.native_exec_command("webpack", ["serve", "--help"])
            end

      # Restore output before running command
      $stdout = original_stdout
      $stderr = original_stderr

      # Capture help output
      require "open3"
      stdout, _stderr, status = Open3.capture3(*cmd)
      status.success? ? stdout : nil
    rescue StandardError => e
      # Restore output if error occurs
      $stdout = original_stdout if $stdout != original_stdout
      $stderr = original_stderr if $stderr != original_stderr
      nil
    end

    def self.filter_managed_options(help_text)
      # Remove options that Shakapacker manages
      lines = help_text.lines
      filtered_lines = []
      skip_until_blank = false

      lines.each do |line|
        # Skip managed options
        if line.match?(/^\s*(-c,\s*)?--config\b/) ||
           line.match?(/^\s*--configName\b/) ||
           line.match?(/^\s*--configLoader\b/) ||
           line.match?(/^\s*--nodeEnv\b/) ||
           line.match?(/^\s*--host\b/) ||
           line.match?(/^\s*--port\b/)
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
          Kernel.exec env, *cmd
        end
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

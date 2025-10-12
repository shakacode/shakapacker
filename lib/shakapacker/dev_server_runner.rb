require "shellwords"
require "socket"

require_relative "configuration"
require_relative "dev_server"
require_relative "runner"
require_relative "version"

module Shakapacker
  class DevServerRunner < Shakapacker::Runner
    def self.run(argv)
      # Show Shakapacker help before webpack/rspack dev server help
      if argv.include?("--help") || argv.include?("-h")
        print_help
        puts "\n" + "=" * 80
        puts "WEBPACK/RSPACK DEV SERVER OPTIONS"
        puts "=" * 80
        puts "The following options are passed through to webpack-dev-server/rspack-dev-server:\n\n"
        # Continue to show bundler help by not exiting
      elsif argv.include?("--version") || argv.include?("-v")
        # Handle version flags - show both Shakapacker and bundler versions
        print_version
        puts "\nDev server version:"
        # Continue to show bundler version by not exiting
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

        Configuration:
          Host, port, and HTTPS settings are configured in config/shakapacker.yml
          under the 'dev_server' section.

        Note: --host and --port CLI flags are NOT supported by Shakapacker.
        Please configure these in config/shakapacker.yml instead.

        Examples:
          bin/shakapacker-dev-server                # Start dev server
          bin/shakapacker-dev-server --debug-shakapacker # Debug with Node inspector

        All other options are passed through to webpack-dev-server or rspack-dev-server.
        See their documentation for details:
          Webpack: https://webpack.js.org/configuration/dev-server/
          Rspack:  https://rspack.dev/config/dev-server
      HELP
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

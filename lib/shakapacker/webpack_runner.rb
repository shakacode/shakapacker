require "shellwords"
require "shakapacker/runner"

module Shakapacker
  class WebpackRunner < Shakapacker::Runner
    WEBPACK_COMMANDS = [
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

    def run
      env = Shakapacker::Compiler.env
      env["SHAKAPACKER_CONFIG"] = @shakapacker_config
      env["NODE_OPTIONS"] = ENV["NODE_OPTIONS"] || ""

      cmd = build_cmd

      if @argv.include?("--debug-webpacker")
        Shakapacker.puts_deprecation_message(
          Shakapacker.short_deprecation_message(
            "--debug-webpacker",
            "--debug-shakapacker"
          )
        )
      end

      if @argv.delete("--debug-shakapacker") || @argv.delete("--debug-webpacker")
        env["NODE_OPTIONS"] = "#{env["NODE_OPTIONS"]} --inspect-brk"
      end

      if @argv.delete "--trace-deprecation"
        env["NODE_OPTIONS"] = "#{env["NODE_OPTIONS"]} --trace-deprecation"
      end

      if @argv.delete "--no-deprecation"
        env["NODE_OPTIONS"] = "#{env["NODE_OPTIONS"]} --no-deprecation"
      end

      # Webpack commands are not compatible with --config option.
      if (@argv & WEBPACK_COMMANDS).empty?
        cmd += ["--config", @webpack_config]
      end

      cmd += @argv

      Dir.chdir(@app_path) do
        Kernel.exec env, *cmd
      end
    end

    private

      def build_cmd
        if Shakapacker::Utils::Misc.use_package_json_gem
          return package_json.manager.native_exec_command("webpack")
        end

        return ["#{@node_modules_bin_path}/webpack"] if node_modules_bin_exist?

        ["yarn", "webpack"]
      end

      def node_modules_bin_exist?
        File.exist?("#{@node_modules_bin_path}/webpack")
      end
  end
end

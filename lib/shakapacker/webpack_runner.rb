require "shellwords"

require_relative "runner"

module Shakapacker
  class WebpackRunner < Shakapacker::Runner
    private

      def build_cmd
        package_json.manager.native_exec_command("webpack")
      end
  end
end

require "shellwords"

require_relative "runner"

module Shakapacker
  class RspackRunner < Shakapacker::Runner
    private

      def build_cmd
        package_json.manager.native_exec_command("rspack")
      end
  end
end

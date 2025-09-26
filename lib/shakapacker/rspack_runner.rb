require "shellwords"

require_relative "runner"

module Shakapacker
  class RspackRunner < Shakapacker::Runner
    def self.run(argv)
      $stdout.sync = true
      ENV["NODE_ENV"] ||= (ENV["RAILS_ENV"] == "production") ? "production" : "development"
      new(argv).run
    end

    private

      def build_cmd
        package_json.manager.native_exec_command("rspack")
      end
  end
end

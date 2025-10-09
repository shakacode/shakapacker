require "shellwords"

require_relative "runner"

module Shakapacker
  class WebpackRunner < Shakapacker::Runner
    def self.run(argv)
      $stdout.sync = true
      ENV["NODE_ENV"] ||= %w[development test].include?(ENV["RAILS_ENV"]) ? ENV["RAILS_ENV"] : "production"
      new(argv).run
    end

    private

      def build_cmd
        package_json.manager.native_exec_command("webpack")
      end
  end
end

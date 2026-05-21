# frozen_string_literal: true

require "English"
require "rake/file_utils"

module Shakapacker
  module Utils
    class Misc
      extend FileUtils

      def self.uncommitted_changes?(message_handler)
        return false if ENV["COVERAGE"] == "true"

        status = `git status --porcelain`
        return false if $CHILD_STATUS.success? && status.empty?

        error = if $CHILD_STATUS.success?
          "You have uncommitted code. Please commit or stash your changes before continuing"
                else
                  "You do not have Git installed. Please install Git, and commit your changes before continuing"
        end
        message_handler.add_error(error)
        true
      end

      def self.object_to_boolean(value)
        [true, "true", "yes", 1, "1", "t"].include?(value.instance_of?(String) ? value.downcase : value)
      end

      # Executes a string or an array of strings in a shell in the given directory in an unbundled environment
      def self.sh_in_dir(dir, *shell_commands)
        shell_commands.flatten.each { |shell_command| sh %(cd '#{dir}' && #{shell_command.strip}) }
      end

      # True if the file at +path+ has a JavaScript (Node) shebang line.
      # Used by the export_bundler_config rake task to dispatch legacy
      # `#!/usr/bin/env node` binstubs left over from older Shakapacker
      # versions instead of trying to parse them as Ruby.
      def self.js_binstub?(path)
        return false unless File.file?(path)

        shebang = File.open(path, "rb") { |f| f.gets } || ""
        shebang.start_with?("#!") && shebang.include?("node")
      end
    end
  end
end

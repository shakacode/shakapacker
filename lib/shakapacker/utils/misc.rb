# frozen_string_literal: true

require "English"
require "rake/file_utils"
require "shellwords"

module Shakapacker
  module Utils
    class Misc
      extend FileUtils

      NODE_BINSTUB_EXECUTABLES = %w[node nodejs].freeze
      private_constant :NODE_BINSTUB_EXECUTABLES

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

      def self.js_binstub_executable(path)
        return nil unless File.file?(path)

        shebang = File.open(path, "rb") { |f| f.gets }.to_s
        return nil unless shebang.start_with?("#!")

        shebang_tokens = begin
          Shellwords.split(shebang.delete_prefix("#!"))
        rescue ArgumentError
          return nil
        end
        executable = shebang_tokens.first.to_s

        if File.basename(executable) == "env"
          shebang_tokens = shebang_tokens.drop(1)
          shebang_tokens.shift while shebang_tokens.first&.start_with?("-")
          executable = shebang_tokens.first.to_s
        end

        NODE_BINSTUB_EXECUTABLES.include?(File.basename(executable)) ? executable : nil
      end
    end
  end
end

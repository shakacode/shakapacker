# frozen_string_literal: true

require "English"
require "rake/file_utils"

# TODO:
# add test
module Shakapacker
  module TaskHelpers
    extend FileUtils

    # Returns the root folder of the shakapacker gem
    def gem_root
      File.expand_path("..", __dir__)
    end

    # Returns the folder where examples are located
    def examples_dir
      File.join(gem_root, "gen-examples", "examples")
    end

    def dummy_app_dir
      File.join(gem_root, "spec/dummy")
    end

    def bundle_install_in(dir)
      unbundled_sh_in_dir(dir, "bundle install")
    end

    def uncommitted_changes?(message_handler)
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

    # Executes a string or an array of strings in a shell in the given directory in an unbundled environment
    def sh_in_dir(dir, *shell_commands)
      shell_commands.flatten.each { |shell_command| sh %(cd #{dir} && #{shell_command.strip}) }
    end

    def unbundled_sh_in_dir(dir, *shell_commands)
      Dir.chdir(dir) do
        # Without `with_unbundled_env`, running bundle in the child directories won't correctly
        # update the Gemfile.lock
        Bundler.with_unbundled_env do
          shell_commands.flatten.each do |shell_command|
            sh(shell_command.strip)
          end
        end
      end
    end

    def object_to_boolean(value)
      [true, "true", "yes", 1, "1", "t"].include?(value.instance_of?(String) ? value.downcase : value)
    end

    # Runs bundle exec using that directory's Gemfile
    def bundle_exec(dir: nil, args: nil, env_vars: "")
      sh_in_dir(dir, "#{env_vars} #{args}")
    end

    def generators_source_dir
      File.join(gem_root, "lib/generators/shakapacker")
    end

    def symbolize_keys(hash)
      hash.each_with_object({}) do |(key, value), new_hash|
        new_key = key.is_a?(String) ? key.to_sym : key
        new_value = value.is_a?(Hash) ? symbolize_keys(value) : value
        new_hash[new_key] = new_value
      end
    end
  end
end

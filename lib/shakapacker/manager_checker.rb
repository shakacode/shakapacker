# frozen_string_literal: true
require "shakapacker/version"
require "package_json"

module Shakapacker
  class ManagerChecker
    class Error < StandardError; end

    MANAGER_LOCKS = {
      bun: "bun.lockb",
      npm: "package-lock.json",
      pnpm: "pnpm-lock.yaml",
      yarn: "yarn.lock"
    }

    # Emits a warning if it's not obvious what package manager to use
    def warn_unless_package_manager_is_obvious!
      return if package_manager_set?

      guessed_manager = guess_manager

      return if guess_manager == :npm

      Shakapacker.puts_deprecation_message(<<~MSG)
        You have not got "packageManager" set in your package.json meaning that Shakapacker will use npm
        but you've got a #{MANAGER_LOCKS[guessed_manager]} file meaning you probably want
        to be using #{guessed_manager} instead.

        To make this happen, set "packageManager" in your package.json to #{guessed_manager}@#{guess_manager_version}
      MSG
    end

    def package_manager_set?
      !PackageJson.read.fetch("packageManager", nil).nil?
    end

    def guess_manager_version
      require "open3"

      command = "#{guess_manager} --version"
      stdout, stderr, status = Open3.capture3(command)

      unless status.success?
        raise Error, "#{command} failed with exit code #{status.exitstatus}: #{stderr}"
      end

      stdout.chomp
    end

    def guess_manager
      MANAGER_LOCKS.find { |_, lock| File.exist?(lock) }&.first || :npm
    end
  end
end

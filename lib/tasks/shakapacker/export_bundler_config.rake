require "shakapacker/utils/misc"

namespace :shakapacker do
  desc <<~DESC
    Export webpack or rspack configuration for debugging and analysis

    Exports your resolved webpack/rspack configuration in human-readable formats.
    Use this to debug configuration issues, compare environments, or analyze
    client vs server bundle differences.

    Usage:
      rake shakapacker:export_bundler_config -- [OPTIONS]

    Quick Start (Recommended):
      rails shakapacker:export_bundler_config --doctor

    This exports all configs (dev + prod, client + server) to shakapacker-config-exports/
    directory in annotated YAML format - perfect for troubleshooting.

    Common Options:
      --doctor              Export everything for troubleshooting (recommended)
      --save                Save current environment configs to files
      --save-dir=<dir>      Custom output directory (requires --save)
      --env=development|production|test    Specify environment
      --client-only         Export only client config
      --server-only         Export only server config
      --format=yaml|json|inspect           Output format
      --help, -h            Show detailed help

    Examples:
      # Export all configs for troubleshooting
      bundle exec rake shakapacker:export_bundler_config -- --doctor

      # Save production client config
      bundle exec rake shakapacker:export_bundler_config -- --save --env=production --client-only

      # View development config in terminal
      bundle exec rake shakapacker:export_bundler_config

      # Show detailed help
      bundle exec rake shakapacker:export_bundler_config -- --help

    The task automatically falls back to the gem version if bin/shakapacker-config
    binstub is not installed. To install all binstubs, run: bundle exec rake shakapacker:binstubs
  DESC
  task :export_bundler_config do
    # Try to use the binstub if it exists, otherwise use the gem's version
    bin_path = Rails.root.join("bin/shakapacker-config")

    unless File.file?(bin_path)
      # Binstub not installed, use the gem's version directly
      gem_bin_path = File.expand_path("../../install/bin/shakapacker-config", __dir__)

      $stderr.puts "Note: bin/shakapacker-config binstub not found."
      $stderr.puts "Using gem version directly. To install the binstub, run: rake shakapacker:binstubs"
      $stderr.puts ""

      Dir.chdir(Rails.root) do
        Kernel.exec(RbConfig.ruby, gem_bin_path, *ARGV[1..])
      end
    else
      # Pass through command-line arguments after the task name.
      #
      # Modern Ruby binstubs (the current default) are invoked with
      # RbConfig.ruby so they run under the same Ruby as Rake — this avoids
      # version-manager/shebang mismatches and works on Windows.
      #
      # Legacy JavaScript binstubs left over from earlier Shakapacker
      # versions (`#!/usr/bin/env node`) are invoked through Node until
      # users refresh them with `rake shakapacker:binstubs`.
      js_binstub_executable = Shakapacker::Utils::Misc.js_binstub_executable(bin_path)

      Dir.chdir(Rails.root) do
        if js_binstub_executable
          $stderr.puts "Note: bin/shakapacker-config is a legacy JavaScript binstub."
          $stderr.puts "Run `bundle exec rake shakapacker:binstubs` to upgrade to the Ruby binstub."
          $stderr.puts ""
          begin
            Kernel.exec(js_binstub_executable, bin_path.to_s, *ARGV[1..])
          rescue Errno::ENOENT
            abort "Error: '#{js_binstub_executable}' was not found in PATH.\n" \
                  "Run `bundle exec rake shakapacker:binstubs` to upgrade to the Ruby binstub."
          end
        else
          Kernel.exec(RbConfig.ruby, bin_path.to_s, *ARGV[1..])
        end
      end
    end
  end
end

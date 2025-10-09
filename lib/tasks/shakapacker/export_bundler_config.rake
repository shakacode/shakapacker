namespace :shakapacker do
  desc <<~DESC
    Export webpack or rspack configuration for debugging and analysis

    Exports your resolved webpack/rspack configuration in human-readable formats.
    Use this to debug configuration issues, compare environments, or analyze
    client vs server bundle differences.

    Usage:
      rails shakapacker:export_bundler_config [OPTIONS]
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
      rails shakapacker:export_bundler_config --doctor

      # Save production client config
      rails shakapacker:export_bundler_config --save --env=production --client-only

      # View development config in terminal
      rails shakapacker:export_bundler_config

      # Show detailed help
      rails shakapacker:export_bundler_config --help

    Note: When using 'rake', you must use '--' to separate rake options from task arguments.
          Example: rake shakapacker:export_bundler_config -- --doctor

    The task automatically falls back to the gem version if bin/export-bundler-config
    binstub is not installed. To install all binstubs, run: rails shakapacker:binstubs
  DESC
  task :export_bundler_config do
    # Try to use the binstub if it exists, otherwise use the gem's version
    bin_path = Rails.root.join("bin/export-bundler-config")

    unless File.exist?(bin_path)
      # Binstub not installed, use the gem's version directly
      gem_bin_path = File.expand_path("../../install/bin/export-bundler-config", __dir__)

      $stderr.puts "Note: bin/export-bundler-config binstub not found."
      $stderr.puts "Using gem version directly. To install the binstub, run: rake shakapacker:binstubs"
      $stderr.puts ""

      Dir.chdir(Rails.root) do
        exec("node", gem_bin_path, *ARGV[1..])
      end
    else
      # Pass through command-line arguments after the task name
      # Use exec to replace the rake process with the export script
      # This ensures proper exit codes and signal handling
      Dir.chdir(Rails.root) do
        exec(bin_path.to_s, *ARGV[1..])
      end
    end
  end
end

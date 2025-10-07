namespace :shakapacker do
  desc "Export webpack or rspack configuration for analysis"
  task :export_config do
    # Try to use the binstub if it exists, otherwise use the gem's version
    bin_path = Rails.root.join("bin/export-config")

    unless File.exist?(bin_path)
      # Binstub not installed, use the gem's version directly
      gem_bin_path = File.expand_path("../../install/bin/export-config", __dir__)

      $stderr.puts "Note: bin/export-config binstub not found."
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

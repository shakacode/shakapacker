require "shakapacker/configuration"

namespace :shakapacker do
  desc "Export webpack or rspack configuration for analysis"
  task :export_config do
    bin_path = Rails.root.join("bin/export-config")

    unless File.exist?(bin_path)
      $stderr.puts "Error: bin/export-config not found"
      $stderr.puts "Please ensure Shakapacker is properly installed"
      exit 1
    end

    # Pass through any environment variables and command-line arguments
    Dir.chdir(Rails.root) do
      system(bin_path.to_s, *ARGV[1..])
    end
  end
end

# frozen_string_literal: true

module ShakapackerAutoSetup
  def self.ensure_config!(app_root)
    config_dir = File.join(app_root, "config")
    shakapacker_config = File.join(config_dir, "shakapacker.yml")
    webpack_config = File.join(config_dir, "shakapacker-webpack.yml")

    return if File.exist?(shakapacker_config)
    return unless File.exist?(webpack_config)

    require "fileutils"
    FileUtils.cp(webpack_config, shakapacker_config)

    $stderr.puts "Auto-configured with webpack (copied shakapacker-webpack.yml -> shakapacker.yml)"
    $stderr.puts "To switch bundlers, use: bin/test-bundler [webpack|rspack]"
    $stderr.puts ""
  end
end

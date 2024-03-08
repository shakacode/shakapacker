require "shakapacker/version"
require "shakapacker/utils/misc"

namespace :shakapacker do
  desc "Provide information on Shakapacker's environment"
  task :info do
    Dir.chdir(Rails.root) do
      $stdout.puts "Ruby: #{`ruby --version`}"
      $stdout.puts "Rails: #{Rails.version}"
      $stdout.puts "Shakapacker: #{Shakapacker::VERSION}"
      $stdout.puts "Node: #{`node --version`}"

      require "package_json"

      pj_manager = PackageJson.read.manager

      $stdout.puts "#{pj_manager.binary}: #{pj_manager.version}"

      node_package_version = Shakapacker::VersionChecker.build.node_package_version.raw

      $stdout.puts "\n"
      $stdout.puts "shakapacker: #{node_package_version}"

      $stdout.puts "Is bin/shakapacker present?: #{File.exist? 'bin/shakapacker'}"
      $stdout.puts "Is bin/shakapacker-dev-server present?: #{File.exist? 'bin/shakapacker-dev-server'}"
    end
  end
end

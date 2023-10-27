require "shakapacker/utils/misc"

namespace :shakapacker do
  desc "Verifies if the expected JS package manager is installed"
  task :check_manager do |task|
    unless Shakapacker::Utils::Misc.use_package_json_gem
      prefix = task.name.split(/#|shakapacker:/).first
      Rake::Task["#{prefix}shakapacker:check_manager"].invoke
      next
    end

    require "package_json"

    package_json = PackageJson.read
    pm = package_json.manager.binary

    begin
      version = package_json.manager.version

      $stdout.puts "using #{pm}@#{version} to manage dependencies and scripts in package.json"
    rescue PackageJson::Error
      $stderr.puts "#{pm} not installed - please ensure it is installed before trying again"
      $stderr.puts "Exiting!"
      exit!
    end
  end
end

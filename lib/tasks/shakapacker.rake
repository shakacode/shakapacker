tasks = {
  "shakapacker:info"                    => "Provides information on Shakapacker's environment",
  "shakapacker:install"                 => "Installs and setup webpack with Yarn",
  "shakapacker:compile"                 => "Compiles webpack bundles based on environment",
  "shakapacker:clean"                   => "Remove old compiled webpacks",
  "shakapacker:clobber"                 => "Removes the webpack compiled output directory",
  "shakapacker:check_node"              => "Verifies if Node.js is installed",
  "shakapacker:check_yarn"              => "Verifies if Yarn is installed",
  "shakapacker:check_binstubs"          => "Verifies that bin/shakapacker is present",
  "shakapacker:binstubs"                => "Installs Shakapacker binstubs in this application",
  "shakapacker:verify_install"          => "Verifies if Shakapacker is installed",
}.freeze

desc "Lists all available tasks in Shakapacker"
task :shakapacker do
  puts "Available Shakapacker tasks are:"
  tasks.each { |task, message| puts task.ljust(30) + message }
end

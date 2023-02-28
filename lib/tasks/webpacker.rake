tasks = {
  "webpacker:info"                    => "DEPRECATED - Provides information on Shakapacker's environment",
  "webpacker:install"                 => "DEPRECATED - Installs and setup webpack with Yarn",
  "webpacker:compile"                 => "DEPRECATED - Compiles webpack bundles based on environment",
  "webpacker:clean"                   => "DEPRECATED - Remove old compiled bundles",
  "webpacker:clobber"                 => "DEPRECATED - Removes the webpack compiled output directory",
  "webpacker:check_node"              => "DEPRECATED - Verifies if Node.js is installed",
  "webpacker:check_yarn"              => "DEPRECATED - Verifies if Yarn is installed",
  "webpacker:check_binstubs"          => "DEPRECATED - Verifies that bin/shakapacker is present",
  "webpacker:binstubs"                => "DEPRECATED - Installs Shakapacker binstubs in this application",
  "webpacker:verify_install"          => "DEPRECATED - Verifies if Shakapacker is installed",
}.freeze

desc "DEPRECATED - Lists all available tasks in Webpacker"
task :webpacker do |task|
  puts "DEPRECATED - Available Webpacker tasks are:"
  tasks.each { |task, message| puts task.ljust(30) + message }

  Shakapacker.puts_rake_deprecation_message(task.name)
end

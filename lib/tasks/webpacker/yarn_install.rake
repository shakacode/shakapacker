namespace :webpacker do
  desc "DEPRECATED - Support for older Rails versions. Install all JavaScript dependencies as specified via Yarn"
  task :yarn_install do |task|
    Shakapacker.puts_rake_deprecation_message(task.name)

    prefix = task.name.split(/#|webpacker:/).first
    Rake::Task["#{prefix}shakapacker:yarn_install"].invoke
  end
end

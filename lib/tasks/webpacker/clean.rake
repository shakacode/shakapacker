namespace :webpacker do
  desc "DEPRECATED - Remove old compiled bundles"
  task :clean, [:keep, :age] do |task, args|
    Shakapacker.puts_rake_deprecation_message(task.name)

    prefix = task.name.split(/#|webpacker:/).first
    Rake::Task["#{prefix}shakapacker:clean"].invoke(args.keep, args.age)
  end
end

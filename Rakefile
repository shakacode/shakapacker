# frozen_string_literal: true
require "bundler/gem_tasks"
require "pathname"

desc "Run all specs"
task test: ["run_spec:all_specs"]

task default: :test

namespace :run_spec do
  desc "Run shakapacker specs"
  task :gem do
    puts "Running Shakapacker gem specs"
    sh("bundle exec rspec spec/shakapacker/*_spec.rb")
  end

  desc "Run backward compatibility specs"
  task :gem_bc do
    puts "Running Shakapacker gem specs for backward compatibility"
    sh("bundle exec rspec spec/backward_compatibility_specs/*_spec.rb")
  end

  desc "Run specs in the dummy app"
  task :dummy do
    puts "Running dummy app specs"
    spec_dummy_dir = Pathname.new(File.join("spec", "dummy")).realpath
    Bundler.with_unbundled_env do
      sh_in_dir(".", "yalc publish")
      sh_in_dir(spec_dummy_dir, [
        "bundle install",
        "yalc link shakapacker",
        "yarn install",
        "bundle exec rspec"
      ])
    end
  end

  desc "Run generator specs"
  task :generator do
    sh("bundle exec rspec spec/generator_specs/*_spec.rb")
  end

  desc "Run all specs"
  task all_specs: %i[gem gem_bc dummy generator] do
    puts "Completed all RSpec tests"
  end
end

def sh_in_dir(dir, *shell_commands)
  Shakapacker::Utils::Misc.sh_in_dir(dir, *shell_commands)
end

# frozen_string_literal: true
require "bundler/gem_tasks"

begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:test)
rescue LoadError
end

task default: :test

desc "Run backward compatibility specs"
task :test_bc do
  system("bundle exec rspec spec/backward_compatibility_specs/*_spec_bc.rb")
end

# frozen_string_literal: true
require "bundler/gem_tasks"

begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:test)
rescue LoadError
end

task default: :test

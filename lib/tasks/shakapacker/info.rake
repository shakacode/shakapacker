require "shakapacker/version"

namespace :shakapacker do
  desc "Provide information on Shakapacker's environment"
  task :info do
    Dir.chdir(Rails.root) do
      $stdout.puts "Ruby: #{`ruby --version`}"
      $stdout.puts "Rails: #{Rails.version}"
      $stdout.puts "Shakapacker: #{Shakapacker::VERSION}"
      $stdout.puts "Node: #{`node --version`}"
      $stdout.puts "Yarn: #{`yarn --version`}"

      $stdout.puts "\n"
      $stdout.puts "shakapacker: \n#{`npm list shakapacker version`}"

      $stdout.puts "Is bin/shakapacker present?: #{File.exist? 'bin/shakapacker'}"
      $stdout.puts "Is bin/shakapacker-dev-server present?: #{File.exist? 'bin/shakapacker-dev-server'}"
      $stdout.puts "Is bin/yarn present?: #{File.exist? 'bin/yarn'}"
    end
  end
end

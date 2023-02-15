namespace :shakapacker do
  desc "Verifies that bin/shakapacker is present"
  task :check_binstubs do
    unless File.exist?(Rails.root.join("bin/shakapacker"))
      $stderr.puts "shakapacker binstub not found.\n"\
           "Have you run rails shakapacker:install ?\n"\
           "Make sure the bin directory and bin/shakapacker are not included in .gitignore\n"\
           "Exiting!"
      exit!
    end
  end
end

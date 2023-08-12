namespace :shakapacker do
  desc "Verifies that bin/shakapacker is present"
  task :check_binstubs do
    verify_file_existence("bin/shakapacker", "bin/webpacker")
    verify_file_existence("bin/shakapacker-dev-server", "bin/webpacker-dev-server")
  end
end

def verify_file_existance(main_file, alternative_file)
  puts "verify_file_existance is deprecated - use verify_file_existence instead"
  verify_file_existence(main_file, alternative_file)
end

def verify_file_existence(main_file, alternative_file)
  unless File.exist?(Rails.root.join(main_file))
    if File.exist?(Rails.root.join(alternative_file))
      Shakapacker.puts_deprecation_message(
        Shakapacker.short_deprecation_message(
          alternative_file,
          main_file
        )
      )
    else
      puts <<~MSG
        Couldn't find shakapacker binstubs!
        Possible solutions:
        - Ensure you have run `rails shakapacker:install`.
        - Run `rails shakapacker:binstubs` if you have already installed shakapacker.
        - Ensure the `bin` directory, `bin/shakapacker`, and `bin/shakapacker-dev-server` are not included in .gitignore.
      MSG
      exit!
    end
  end
end

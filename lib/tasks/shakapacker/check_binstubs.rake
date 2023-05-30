namespace :shakapacker do
  desc "Verifies that bin/shakapacker is present"
  task :check_binstubs do
    unless File.exist?(Rails.root.join("bin/shakapacker"))
      if File.exist?(Rails.root.join("bin/webpacker"))
        Shakapacker.puts_deprecation_message(
          Shakapacker.short_deprecation_message(
            "bin/webpacker",
            "bin/shakapacker"
          )
        )
      else
        puts <<~MSG
          Could't find shakapacker binstubs!
          Possible solutions:
          - Ensure you have run `rails shakapacker:install`.
          - Run `rails shakapacker:binstubs` if you have already installed shakapacker.
          - Ensure the `bin` directory and `bin/shakapacker` are not included in .gitignore.
        MSG
        exit!
      end
    end
  end
end

require "shakapacker/swc_migrator"

namespace :shakapacker do
  desc "Migrate from Babel to SWC transpiler"
  task :migrate_to_swc do
    migrator = Shakapacker::SwcMigrator.new(Rails.root)
    results = migrator.migrate_to_swc

    # Provide cleanup recommendations if babel packages found
    if results[:babel_packages_found].any?
      puts "\n🧹 Cleanup Recommendations:"
      puts "   Found the following Babel packages in your package.json:"
      results[:babel_packages_found].each do |package|
        puts "   - #{package}"
      end
      puts "\n   To remove them, run:"
      puts "   rails shakapacker:clean_babel_packages"
    end

    # Run package manager install if packages were added
    if results[:packages_installed].any?
      puts "\n🔧 Running npm/yarn install..."
      if File.exist?(Rails.root.join("yarn.lock"))
        system("yarn install")
      else
        system("npm install")
      end
    end
  end

  desc "Remove Babel packages after migrating to SWC"
  task :clean_babel_packages do
    migrator = Shakapacker::SwcMigrator.new(Rails.root)
    result = migrator.clean_babel_packages

    # Run package manager install if packages were removed
    if result[:removed_packages].any?
      puts "\n🔧 Running npm/yarn install to update lock file..."
      if File.exist?(Rails.root.join("yarn.lock"))
        system("yarn install")
      else
        system("npm install")
      end
    end
  end
end

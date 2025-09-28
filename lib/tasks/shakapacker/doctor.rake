require "json"

namespace :shakapacker do
  desc "Checks for common Shakapacker configuration issues and missing dependencies"
  task doctor: :environment do
    puts "Running Shakapacker doctor..."
    puts "=" * 60

    issues = []
    warnings = []

    # Check if config file exists
    unless Shakapacker.config.config_path.exist?
      issues << "Configuration file not found at #{Shakapacker.config.config_path}"
    else
      puts "✓ Configuration file found"

      # Check JavaScript transpiler dependencies
      transpiler = Shakapacker.config.javascript_transpiler
      if transpiler && transpiler != "none"
        check_dependency("#{transpiler}-loader", issues, "JavaScript transpiler")
      end

      # Check common loaders based on what files exist in the project
      source_path = Shakapacker.config.source_path
      if source_path.exist?
        # Check for TypeScript files and ts-loader
        if Dir.glob(File.join(source_path, "**/*.{ts,tsx}")).any?
          if transpiler == "babel"
            check_optional_dependency("@babel/preset-typescript", warnings, "TypeScript with Babel")
          elsif transpiler != "esbuild" && transpiler != "swc"
            check_optional_dependency("ts-loader", warnings, "TypeScript")
          end
        end

        # Check for Sass/SCSS files and sass-loader
        if Dir.glob(File.join(source_path, "**/*.{sass,scss}")).any?
          check_dependency("sass-loader", issues, "Sass/SCSS")
          check_dependency("sass", issues, "Sass/SCSS (sass package)")
        end

        # Check for Less files and less-loader
        if Dir.glob(File.join(source_path, "**/*.less")).any?
          check_dependency("less-loader", issues, "Less")
          check_dependency("less", issues, "Less (less package)")
        end

        # Check for Stylus files and stylus-loader
        if Dir.glob(File.join(source_path, "**/*.{styl,stylus}")).any?
          check_dependency("stylus-loader", issues, "Stylus")
          check_dependency("stylus", issues, "Stylus (stylus package)")
        end
      end

      # Check CSS extraction dependencies if needed
      check_dependency("css-loader", issues, "CSS")
      check_dependency("style-loader", issues, "CSS (style-loader)")
      check_dependency("mini-css-extract-plugin", warnings, "CSS extraction (optional)")

      # Check core webpack/rspack dependencies
      bundler = Shakapacker.config.assets_bundler
      if bundler == "webpack"
        check_dependency("webpack", issues, "webpack")
        check_dependency("webpack-cli", issues, "webpack CLI")
      elsif bundler == "rspack"
        check_dependency("@rspack/core", issues, "Rspack")
        check_dependency("@rspack/cli", issues, "Rspack CLI")
      end

      # Check for PostCSS if config exists
      if File.exist?(Rails.root.join("postcss.config.js"))
        check_dependency("postcss", issues, "PostCSS")
        check_dependency("postcss-loader", issues, "PostCSS")
      end
    end

    # Check Node.js
    begin
      node_version = `node --version`.strip
      puts "✓ Node.js #{node_version} found"
    rescue Errno::ENOENT
      issues << "Node.js is not installed or not in PATH"
    end

    # Check package manager
    package_manager = detect_package_manager
    if package_manager
      puts "✓ Package manager: #{package_manager}"
    else
      issues << "No package manager lock file found (package-lock.json, yarn.lock, or pnpm-lock.yaml)"
    end

    # Check if binstub exists
    binstub_path = Rails.root.join("bin/shakapacker")
    if binstub_path.exist?
      puts "✓ Shakapacker binstub found"
    else
      warnings << "Shakapacker binstub not found at bin/shakapacker. Run 'rails shakapacker:binstubs' to create it."
    end

    # Report results
    puts "=" * 60

    if issues.empty? && warnings.empty?
      puts "✅ No issues found! Shakapacker appears to be configured correctly."
    else
      if issues.any?
        puts "❌ Issues found (#{issues.length}):"
        issues.each_with_index do |issue, index|
          puts "  #{index + 1}. #{issue}"
        end
        puts ""
      end

      if warnings.any?
        puts "⚠️  Warnings (#{warnings.length}):"
        warnings.each_with_index do |warning, index|
          puts "  #{index + 1}. #{warning}"
        end
        puts ""
      end

      puts "To fix missing dependencies, run:"
      puts "  #{package_manager_install_command(package_manager)}"

      exit(1) if issues.any?
    end
  end

  private

    def check_dependency(package_name, issues_array, description)
      unless package_installed?(package_name)
        issues_array << "Missing required dependency '#{package_name}' for #{description}"
        false
      else
        puts "✓ #{description}: #{package_name} is installed"
        true
      end
    end

    def check_optional_dependency(package_name, warnings_array, description)
      unless package_installed?(package_name)
        warnings_array << "Optional dependency '#{package_name}' for #{description} is not installed"
        false
      else
        puts "✓ #{description}: #{package_name} is installed"
        true
      end
    end

    def package_installed?(package_name)
      package_json_path = Rails.root.join("package.json")
      return false unless package_json_path.exist?

      package_json = JSON.parse(File.read(package_json_path))
      dependencies = (package_json["dependencies"] || {}).merge(package_json["devDependencies"] || {})
      dependencies.key?(package_name)
    rescue JSON::ParserError
      false
    end

    def detect_package_manager
      return "pnpm" if File.exist?(Rails.root.join("pnpm-lock.yaml"))
      return "yarn" if File.exist?(Rails.root.join("yarn.lock"))
      return "npm" if File.exist?(Rails.root.join("package-lock.json"))
      nil
    end

    def package_manager_install_command(manager)
      case manager
      when "pnpm" then "pnpm add -D [package-name]"
      when "yarn" then "yarn add -D [package-name]"
      when "npm" then "npm install --save-dev [package-name]"
      else "npm install --save-dev [package-name]"
      end
    end
end

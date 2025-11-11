# frozen_string_literal: true

require "yaml"
require "fileutils"

module Shakapacker
  # Provides functionality to switch between webpack and rspack bundlers
  class BundlerSwitcher
    SHAKAPACKER_CONFIG = "config/shakapacker.yml"
    CUSTOM_DEPS_CONFIG = ".shakapacker-switch-bundler-dependencies.yml"

    # Default dependencies for each bundler (package names only, no versions)
    DEFAULT_RSPACK_DEPS = {
      dev: %w[@rspack/cli @rspack/plugin-react-refresh],
      prod: %w[@rspack/core rspack-manifest-plugin]
    }.freeze

    DEFAULT_WEBPACK_DEPS = {
      dev: %w[webpack webpack-cli webpack-dev-server @pmmmwh/react-refresh-webpack-plugin @swc/core swc-loader],
      prod: %w[webpack-assets-manifest webpack-merge]
    }.freeze

    attr_reader :root_path

    def initialize(root_path = nil)
      @root_path = root_path || (defined?(Rails) ? Rails.root : Pathname.new(Dir.pwd))
    end

    def current_bundler
      config = load_yaml_config(config_path)
      config.dig("default", "assets_bundler") || "webpack"
    end

    def switch_to(bundler, install_deps: false, no_uninstall: false)
      unless %w[webpack rspack].include?(bundler)
        raise ArgumentError, "Invalid bundler: #{bundler}. Must be 'webpack' or 'rspack'"
      end

      current = current_bundler
      if current == bundler && !install_deps
        puts "✅ Already using #{bundler}"
        return
      end

      if current == bundler && install_deps
        puts "✅ Already using #{bundler} - reinstalling dependencies as requested"
        manage_dependencies(bundler, install_deps, switching: false, no_uninstall: no_uninstall)
        return
      end

      update_config(bundler)

      puts "✅ Switched from #{current} to #{bundler}"
      puts ""
      puts "📝 Configuration updated in #{SHAKAPACKER_CONFIG}"

      manage_dependencies(bundler, install_deps, no_uninstall: no_uninstall)

      puts ""
      puts "🎯 Next steps:"
      puts "   1. Restart your dev server: bin/dev"
      puts "   2. Verify build works: bin/shakapacker"
      puts ""
      puts "💡 Tip: Both webpack and rspack can coexist in package.json during migration"
      puts "        Use --install-deps to automatically manage dependencies, or manage manually"
      puts "        Use --no-uninstall to skip removing old bundler packages (faster switching)"
    end

    def init_config
      if File.exist?(custom_config_path)
        puts "⚠️  #{CUSTOM_DEPS_CONFIG} already exists"
        return
      end

      config = {
        "rspack" => {
          "devDependencies" => DEFAULT_RSPACK_DEPS[:dev],
          "dependencies" => DEFAULT_RSPACK_DEPS[:prod]
        },
        "webpack" => {
          "devDependencies" => DEFAULT_WEBPACK_DEPS[:dev],
          "dependencies" => DEFAULT_WEBPACK_DEPS[:prod]
        }
      }

      File.write(custom_config_path, YAML.dump(config))
      puts "✅ Created #{CUSTOM_DEPS_CONFIG}"
      puts ""
      puts "You can now customize the dependencies for each bundler in this file."
      puts "The script will automatically use these custom dependencies when switching bundlers."
    end

    def show_usage
      current = current_bundler
      puts "Current bundler: #{current}"
      puts ""
      puts "Usage:"
      puts "  # Using rake (with -- separator for options)"
      puts "  rake shakapacker:switch_bundler [webpack|rspack] -- [OPTIONS]"
      puts ""
      puts "  # Using rails (with environment variables)"
      puts "  rails shakapacker:switch_bundler BUNDLER=[webpack|rspack] [INSTALL_DEPS=true] [NO_UNINSTALL=true]"
      puts ""
      puts "Options:"
      puts "  --install-deps    Automatically install/uninstall dependencies (rake only)"
      puts "  --no-uninstall    Skip uninstalling old bundler packages (rake only)"
      puts "  --init-config     Create #{CUSTOM_DEPS_CONFIG} with default dependencies"
      puts "  --help, -h        Show this help message"
      puts ""
      puts "Environment Variables (for rails command):"
      puts "  BUNDLER           Target bundler: 'webpack' or 'rspack'"
      puts "  INSTALL_DEPS      Set to 'true' to automatically install/uninstall dependencies"
      puts "  NO_UNINSTALL      Set to 'true' to skip uninstalling old bundler packages"
      puts "  INIT_CONFIG       Set to 'true' to create custom dependencies configuration file"
      puts ""
      puts "Examples:"
      puts "  # Using rake command (note the -- separator)"
      puts "  rake shakapacker:switch_bundler rspack -- --install-deps"
      puts "  rake shakapacker:switch_bundler webpack -- --install-deps --no-uninstall"
      puts "  rake shakapacker:switch_bundler -- --init-config"
      puts ""
      puts "  # Using rails command (with environment variables)"
      puts "  rails shakapacker:switch_bundler BUNDLER=rspack INSTALL_DEPS=true"
      puts "  rails shakapacker:switch_bundler BUNDLER=webpack INSTALL_DEPS=true NO_UNINSTALL=true"
      puts "  rails shakapacker:switch_bundler INIT_CONFIG=true"
    end

    private

      def config_path
        root_path.join(SHAKAPACKER_CONFIG)
      end

      def custom_config_path
        root_path.join(CUSTOM_DEPS_CONFIG)
      end

      def load_dependencies
        if File.exist?(custom_config_path)
          puts "📝 Using custom dependencies from #{CUSTOM_DEPS_CONFIG}"
          begin
            custom = load_yaml_config(custom_config_path)
          rescue Psych::SyntaxError => e
            puts "❌ Error parsing #{CUSTOM_DEPS_CONFIG}: #{e.message}"
            puts "   Please fix the YAML syntax or delete the file to use defaults"
            raise
          end
          rspack_deps = {
            dev: custom.dig("rspack", "devDependencies") || DEFAULT_RSPACK_DEPS[:dev],
            prod: custom.dig("rspack", "dependencies") || DEFAULT_RSPACK_DEPS[:prod]
          }
          webpack_deps = {
            dev: custom.dig("webpack", "devDependencies") || DEFAULT_WEBPACK_DEPS[:dev],
            prod: custom.dig("webpack", "dependencies") || DEFAULT_WEBPACK_DEPS[:prod]
          }
          [rspack_deps, webpack_deps]
        else
          [DEFAULT_RSPACK_DEPS, DEFAULT_WEBPACK_DEPS]
        end
      end

      def update_config(bundler)
        content = File.read(config_path)

        # Replace assets_bundler value (handles spaces, tabs, and various quote styles)
        # Only matches uncommented lines
        content.gsub!(/^([ \t]*assets_bundler:[ \t]*['"]?)(webpack|rspack)(['"]?)/, "\\1#{bundler}\\3")

        # Update javascript_transpiler recommendation for rspack
        # Only update if not already set to swc and only on uncommented lines
        if bundler == "rspack" && content !~ /^[ \t]*javascript_transpiler:[ \t]*['"]?swc['"]?/
          content.gsub!(/^([ \t]*javascript_transpiler:[ \t]*['"]?)\w+(['"]?)/, "\\1swc\\2")
        end

        File.write(config_path, content)
      end

      def manage_dependencies(bundler, install_deps, switching: true, no_uninstall: false)
        rspack_deps, webpack_deps = load_dependencies
        deps_to_install = bundler == "rspack" ? rspack_deps : webpack_deps
        deps_to_remove = bundler == "rspack" ? webpack_deps : rspack_deps

        if install_deps
          puts ""
          puts "📦 Managing dependencies..."
          puts ""

          # Show what will be removed (only when switching and not no_uninstall)
          if switching && !no_uninstall && (!deps_to_remove[:dev].empty? || !deps_to_remove[:prod].empty?)
            puts "   🗑️  Removing:"
            deps_to_remove[:dev].each { |dep| puts "      - #{dep} (dev)" }
            deps_to_remove[:prod].each { |dep| puts "      - #{dep} (prod)" }
            puts ""
          elsif switching && no_uninstall
            puts "   ⏭️  Skipping uninstall (--no-uninstall)"
            puts ""
          end

          # Show what will be installed
          if !deps_to_install[:dev].empty? || !deps_to_install[:prod].empty?
            puts "   📦 Installing:"
            deps_to_install[:dev].each { |dep| puts "      - #{dep} (dev)" }
            deps_to_install[:prod].each { |dep| puts "      - #{dep} (prod)" }
            puts ""
          end

          # Remove old bundler dependencies (only when switching and not no_uninstall)
          if switching && !no_uninstall
            remove_dependencies(deps_to_remove)
          end

          # Install new bundler dependencies
          install_dependencies(deps_to_install)

          puts "   ✅ Dependencies updated"
        else
          print_manual_dependency_instructions(bundler, deps_to_install, deps_to_remove)
        end
      end

      def remove_dependencies(deps)
        package_json = get_package_json

        unless deps[:dev].empty?
          unless package_json.manager.remove(deps[:dev])
            puts "   ⚠️  Warning: Failed to uninstall some dev dependencies"
          end
        end

        unless deps[:prod].empty?
          unless package_json.manager.remove(deps[:prod])
            puts "   ⚠️  Warning: Failed to uninstall some prod dependencies"
          end
        end
      end

      def install_dependencies(deps)
        package_json = get_package_json

        unless deps[:dev].empty?
          unless package_json.manager.add(deps[:dev], type: :dev)
            puts "❌ Failed to install dev dependencies"
            raise "Failed to install dev dependencies"
          end
        end

        unless deps[:prod].empty?
          unless package_json.manager.add(deps[:prod], type: :production)
            puts "❌ Failed to install prod dependencies"
            raise "Failed to install prod dependencies"
          end
        end

        # Run a full install to ensure optional dependencies (like native bindings) are properly resolved
        # This is especially important for packages like @rspack/core that use platform-specific native modules
        unless package_json.manager.install
          puts "❌ Failed to run full install to resolve optional dependencies"
          raise "Failed to run full install"
        end
      end

      def get_package_json
        require "package_json"
        PackageJson.read(root_path)
      end

      def print_manual_dependency_instructions(bundler, deps_to_install, deps_to_remove)
        puts ""
        puts "⚠️  Dependencies not automatically installed (use --install-deps to auto-install)"
        puts ""

        package_manager = detect_package_manager
        target_name = bundler == "rspack" ? "rspack" : "webpack"
        old_name = bundler == "rspack" ? "webpack" : "rspack"

        puts "📦 To install #{target_name} dependencies, run:"
        print_install_commands(package_manager, deps_to_install)
        puts ""
        puts "🗑️  To remove #{old_name} dependencies, run:"
        print_uninstall_commands(package_manager, deps_to_remove)
      end

      def detect_package_manager
        get_package_json.manager.binary
      rescue StandardError
        "npm" # Fallback to npm if detection fails
      end

      def print_install_commands(package_manager, deps)
        case package_manager
        when "yarn"
          puts "   yarn add --dev #{deps[:dev].join(' ')}" unless deps[:dev].empty?
          puts "   yarn add #{deps[:prod].join(' ')}" unless deps[:prod].empty?
        when "pnpm"
          puts "   pnpm add -D #{deps[:dev].join(' ')}" unless deps[:dev].empty?
          puts "   pnpm add #{deps[:prod].join(' ')}" unless deps[:prod].empty?
        when "bun"
          puts "   bun add --dev #{deps[:dev].join(' ')}" unless deps[:dev].empty?
          puts "   bun add #{deps[:prod].join(' ')}" unless deps[:prod].empty?
        else # npm
          puts "   npm install --save-dev #{deps[:dev].join(' ')}" unless deps[:dev].empty?
          puts "   npm install --save #{deps[:prod].join(' ')}" unless deps[:prod].empty?
        end
      end

      def print_uninstall_commands(package_manager, deps)
        case package_manager
        when "yarn"
          puts "   yarn remove #{deps[:dev].join(' ')}" unless deps[:dev].empty?
          puts "   yarn remove #{deps[:prod].join(' ')}" unless deps[:prod].empty?
        when "pnpm"
          puts "   pnpm remove #{deps[:dev].join(' ')}" unless deps[:dev].empty?
          puts "   pnpm remove #{deps[:prod].join(' ')}" unless deps[:prod].empty?
        when "bun"
          puts "   bun remove #{deps[:dev].join(' ')}" unless deps[:dev].empty?
          puts "   bun remove #{deps[:prod].join(' ')}" unless deps[:prod].empty?
        else # npm
          puts "   npm uninstall #{deps[:dev].join(' ')}" unless deps[:dev].empty?
          puts "   npm uninstall #{deps[:prod].join(' ')}" unless deps[:prod].empty?
        end
      end

      # Load YAML config file with Ruby version compatibility
      # Ruby 3.1+ supports aliases: keyword, older versions need YAML.safe_load
      def load_yaml_config(path)
        if YAML.respond_to?(:unsafe_load_file)
          # Ruby 3.1+: Use unsafe_load_file to support aliases/anchors
          YAML.unsafe_load_file(path)
        else
          # Ruby 2.7-3.0: Use safe_load with aliases enabled
          YAML.safe_load(File.read(path), permitted_classes: [], permitted_symbols: [], aliases: true)
        end
      rescue ArgumentError
        # Ruby 2.7 doesn't support aliases keyword - fall back to YAML.load
        YAML.load(File.read(path)) # rubocop:disable Security/YAMLLoad
      end
  end
end

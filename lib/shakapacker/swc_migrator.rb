require "yaml"
require "json"
require "fileutils"
require "logger"
require "pathname"

module Shakapacker
  class SwcMigrator
    attr_reader :root_path, :logger

    BABEL_PACKAGES = [
      "@babel/core",
      "@babel/plugin-proposal-class-properties",
      "@babel/plugin-proposal-object-rest-spread",
      "@babel/plugin-syntax-dynamic-import",
      "@babel/plugin-transform-destructuring",
      "@babel/plugin-transform-regenerator",
      "@babel/plugin-transform-runtime",
      "@babel/preset-env",
      "@babel/preset-react",
      "@babel/preset-typescript",
      "@babel/runtime",
      "babel-loader",
      "babel-plugin-macros",
      "babel-plugin-transform-react-remove-prop-types"
    ].freeze

    SWC_PACKAGES = {
      "@swc/core" => "^1.7.39",
      "swc-loader" => "^0.2.6"
    }.freeze

    DEFAULT_SWCRC_CONFIG = {
      "jsc" => {
        "parser" => {
          "syntax" => "ecmascript",
          "jsx" => true,
          "dynamicImport" => true
        },
        "transform" => {
          "react" => {
            "runtime" => "automatic"
          }
        }
      },
      "module" => {
        "type" => "es6"
      }
    }.freeze

    def initialize(root_path, logger: nil)
      @root_path = Pathname.new(root_path)
      @logger = logger || Logger.new($stdout)
    end

    def migrate_to_swc(run_installer: true)
      logger.info "🔄 Starting migration from Babel to SWC..."

      results = {
        config_updated: update_shakapacker_config,
        packages_installed: install_swc_packages,
        swcrc_created: create_swcrc,
        babel_packages_found: find_babel_packages
      }

      logger.info "🎉 Migration to SWC complete!"
      logger.info "   Note: SWC is approximately 20x faster than Babel for transpilation."
      logger.info "   Please test your application thoroughly after migration."
      logger.info "\n📝 Configuration Info:"
      logger.info "   - .swcrc provides base configuration for all environments"
      logger.info "   - The SWC loader adds automatic environment targeting (via 'env' setting)"
      logger.info "   - You can customize .swcrc, but avoid setting 'jsc.target' as it conflicts with 'env'"

      # Show cleanup recommendations if babel packages found
      if results[:babel_packages_found].any?
        logger.info "\n🧹 Cleanup Recommendations:"
        logger.info "   Found the following Babel packages in your package.json:"
        results[:babel_packages_found].each do |package|
          logger.info "   - #{package}"
        end
        logger.info "\n   To remove them, run:"
        logger.info "   rails shakapacker:clean_babel_packages"
      end

      # Suggest running doctor to verify configuration
      logger.info "\n🩺 Run 'rails shakapacker:doctor' to verify your configuration"

      # Run package manager install if packages were added
      if run_installer && results[:packages_installed].any?
        run_package_manager_install
      end

      results
    end

    def clean_babel_packages(run_installer: true)
      logger.info "🧹 Removing Babel packages..."

      package_json_path = root_path.join("package.json")
      unless package_json_path.exist?
        logger.error "❌ No package.json found"
        return { removed_packages: [], config_files_deleted: [] }
      end

      # Check if ESLint uses Babel parser
      if eslint_uses_babel?
        logger.info "\n⚠️  WARNING: ESLint configuration detected that may use Babel"
        logger.info "   If you use @babel/eslint-parser or babel-eslint, you may need to:"
        logger.info "   1. Keep @babel/core and related Babel packages for ESLint"
        logger.info "   2. Or switch to @typescript-eslint/parser for TypeScript files"
        logger.info "   3. Or use espree (ESLint's default parser) for JavaScript files"
        logger.info "\n   Proceeding with Babel package removal. Check your ESLint config after."
      end

      removed_packages = remove_babel_from_package_json(package_json_path)
      deleted_files = delete_babel_config_files

      if removed_packages.any?
        logger.info "✅ Babel packages removed successfully!"
        run_package_manager_install if run_installer
      else
        logger.info "ℹ️  No Babel packages found to remove"
      end

      { removed_packages: removed_packages, config_files_deleted: deleted_files }
    end

    def find_babel_packages
      package_json_path = root_path.join("package.json")
      return [] unless package_json_path.exist?

      begin
        package_json = JSON.parse(File.read(package_json_path))
        dependencies = package_json["dependencies"] || {}
        dev_dependencies = package_json["devDependencies"] || {}
        all_deps = dependencies.merge(dev_dependencies)

        found_packages = BABEL_PACKAGES.select { |pkg| all_deps.key?(pkg) }
        found_packages
      rescue JSON::ParserError => e
        logger.error "Failed to parse package.json: #{e.message}"
        []
      end
    end

    private

      def eslint_uses_babel?
        # Check for ESLint config files
        eslint_configs = [
          ".eslintrc",
          ".eslintrc.js",
          ".eslintrc.cjs",
          ".eslintrc.yaml",
          ".eslintrc.yml",
          ".eslintrc.json"
        ]

        eslint_configs.each do |config_file|
          config_path = root_path.join(config_file)
          next unless config_path.exist?

          content = File.read(config_path)
          # Check for Babel parser references
          return true if content.match?(/@babel\/eslint-parser|babel-eslint/)
        end

        # Check package.json for eslintConfig
        package_json_path = root_path.join("package.json")
        if package_json_path.exist?
          begin
            package_json = JSON.parse(File.read(package_json_path))
            if package_json["eslintConfig"]
              return true if package_json["eslintConfig"].to_s.match?(/@babel\/eslint-parser|babel-eslint/)
            end

            # Check if Babel ESLint packages are installed
            dependencies = package_json["dependencies"] || {}
            dev_dependencies = package_json["devDependencies"] || {}
            all_deps = dependencies.merge(dev_dependencies)
            return true if all_deps.key?("@babel/eslint-parser") || all_deps.key?("babel-eslint")
          rescue JSON::ParserError
            # Ignore parse errors
          end
        end

        false
      end

      def update_shakapacker_config
        config_path = root_path.join("config/shakapacker.yml")
        return false unless config_path.exist?

        logger.info "📝 Updating shakapacker.yml..."
        config = begin
          YAML.load_file(config_path, aliases: true)
        rescue ArgumentError
          YAML.load_file(config_path)
        end

        config.each do |env, settings|
          next unless settings.is_a?(Hash)

          if settings["babel"]
            logger.info "  - Removing babel config from #{env} environment"
            settings.delete("babel")
          end

          settings["swc"] = true
          logger.info "  - Enabled SWC for #{env} environment"
        end

        File.write(config_path, config.to_yaml)
        logger.info "✅ shakapacker.yml updated"
        true
      rescue StandardError => e
        logger.error "Failed to update config: #{e.message}"
        false
      end

      def install_swc_packages
        package_json_path = root_path.join("package.json")
        return {} unless package_json_path.exist?

        logger.info "📦 Installing SWC dependencies..."
        package_json = JSON.parse(File.read(package_json_path))

        dependencies = package_json["dependencies"] || {}
        dev_dependencies = package_json["devDependencies"] || {}
        installed = {}

        SWC_PACKAGES.each do |package, version|
          unless dependencies[package] || dev_dependencies[package]
            logger.info "  - Adding #{package}@#{version}"
            dev_dependencies[package] = version
            installed[package] = version
          else
            logger.info "  - #{package} already installed"
          end
        end

        if installed.any?
          package_json["devDependencies"] = dev_dependencies
          File.write(package_json_path, JSON.pretty_generate(package_json) + "\n")
          logger.info "✅ package.json updated with SWC dependencies"
        end

        installed
      rescue StandardError => e
        logger.error "Failed to install packages: #{e.message}"
        {}
      end

      def create_swcrc
        swcrc_path = root_path.join(".swcrc")
        if swcrc_path.exist?
          logger.info "ℹ️  .swcrc already exists"
          return false
        end

        logger.info "📄 Creating .swcrc configuration..."
        File.write(swcrc_path, JSON.pretty_generate(DEFAULT_SWCRC_CONFIG) + "\n")
        logger.info "✅ .swcrc created"
        true
      rescue StandardError => e
        logger.error "Failed to create .swcrc: #{e.message}"
        false
      end

      def remove_babel_from_package_json(package_json_path)
        package_json = JSON.parse(File.read(package_json_path))
        dependencies = package_json["dependencies"] || {}
        dev_dependencies = package_json["devDependencies"] || {}
        removed_packages = []

        BABEL_PACKAGES.each do |package|
          if dependencies.delete(package)
            removed_packages << package
            logger.info "  - Removed #{package} from dependencies"
          end
          if dev_dependencies.delete(package)
            removed_packages << package
            logger.info "  - Removed #{package} from devDependencies"
          end
        end

        if removed_packages.any?
          package_json["dependencies"] = dependencies
          package_json["devDependencies"] = dev_dependencies
          File.write(package_json_path, JSON.pretty_generate(package_json) + "\n")
          logger.info "✅ package.json updated"
        end

        removed_packages.uniq
      rescue StandardError => e
        logger.error "Failed to remove packages: #{e.message}"
        []
      end

      def delete_babel_config_files
        deleted_files = []
        babel_config_files = [".babelrc", "babel.config.js", ".babelrc.js", "babel.config.json"]

        babel_config_files.each do |file|
          file_path = root_path.join(file)
          if file_path.exist?
            logger.info "  - Removing #{file}"
            File.delete(file_path)
            deleted_files << file
          end
        end

        deleted_files
      rescue StandardError => e
        logger.error "Failed to delete config files: #{e.message}"
        []
      end

      def run_package_manager_install
        logger.info "\n🔧 Running npm/yarn install..."

        yarn_lock = root_path.join("yarn.lock")
        pnpm_lock = root_path.join("pnpm-lock.yaml")

        if yarn_lock.exist?
          system("yarn install")
        elsif pnpm_lock.exist?
          system("pnpm install")
        else
          system("npm install")
        end
      end

      def package_manager
        yarn_lock = root_path.join("yarn.lock")
        pnpm_lock = root_path.join("pnpm-lock.yaml")

        if yarn_lock.exist?
          "yarn"
        elsif pnpm_lock.exist?
          "pnpm"
        else
          "npm"
        end
      end
  end
end

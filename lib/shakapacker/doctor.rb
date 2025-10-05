require "json"
require "pathname"
require "open3"
require "semantic_range"

module Shakapacker
  class Doctor
    attr_reader :config, :root_path, :issues, :warnings, :info

    def initialize(config = nil, root_path = nil)
      @config = config || Shakapacker.config
      @root_path = root_path || (defined?(Rails) ? Rails.root : Pathname.new(Dir.pwd))
      @issues = []
      @warnings = []
      @info = []
    end

    def run
      perform_checks
      report_results
    end

    def success?
      @issues.empty?
    end

    private

      def perform_checks
        # Core configuration checks
        check_config_file
        check_entry_points if config_exists?
        check_output_paths if config_exists?
        check_deprecated_config if config_exists?

        # Environment checks
        check_node_installation
        check_package_manager
        check_binstub
        check_version_consistency
        check_environment_consistency

        # Dependency checks
        check_javascript_transpiler_dependencies if config_exists?
        check_css_dependencies
        check_css_modules_configuration
        check_bundler_dependencies if config_exists?
        check_file_type_dependencies if config_exists?
        check_sri_dependencies if config_exists?
        check_peer_dependencies

        # Platform and migration checks
        check_windows_platform
        check_legacy_webpacker_files

        # Build and compilation checks
        check_assets_compilation if config_exists?
      end

      def check_config_file
        unless config.config_path.exist?
          @issues << "Configuration file not found at #{config.config_path}"
        end
      end

      def check_entry_points
        # Check for invalid configuration first
        if config.data[:source_entry_path] == "/" && config.nested_entries?
          @issues << "Invalid configuration: cannot use '/' as source_entry_path with nested_entries: true"
          return  # Don't try to check files when config is invalid
        end

        source_entry_path = config.source_path.join(config.data[:source_entry_path] || "packs")

        unless source_entry_path.exist?
          @issues << "Source entry path #{source_entry_path} does not exist"
          return
        end

        # Check for at least one entry point
        entry_files = Dir.glob(File.join(source_entry_path, "**/*.{js,jsx,ts,tsx,coffee}"))
        if entry_files.empty?
          @warnings << "No entry point files found in #{source_entry_path}"
        end
      end

      def check_output_paths
        public_output_path = config.public_output_path

        # Check if output directory is writable
        if public_output_path.exist?
          unless File.writable?(public_output_path)
            @issues << "Public output path #{public_output_path} is not writable"
          end
        elsif public_output_path.parent.exist?
          unless File.writable?(public_output_path.parent)
            @issues << "Cannot create public output path #{public_output_path} (parent directory not writable)"
          end
        end

        # Check manifest.json
        manifest_path = config.manifest_path
        if manifest_path.exist?
          unless File.readable?(manifest_path)
            @issues << "Manifest file #{manifest_path} exists but is not readable"
          end

          # Check if manifest is stale
          begin
            manifest_content = JSON.parse(File.read(manifest_path))
            if manifest_content.empty?
              @warnings << "Manifest file is empty - you may need to run 'rails assets:precompile'"
            end
          rescue JSON::ParserError
            @issues << "Manifest file #{manifest_path} contains invalid JSON"
          end
        end

        # Check cache path
        cache_path = config.cache_path
        if cache_path.exist? && !File.writable?(cache_path)
          @issues << "Cache path #{cache_path} is not writable"
        end
      end

      def check_deprecated_config
        config_file = File.read(config.config_path)

        if config_file.include?("webpack_loader:")
          @warnings << "Deprecated config: 'webpack_loader' should be renamed to 'javascript_transpiler'"
        end

        if config_file.include?("bundler:")
          @warnings << "Deprecated config: 'bundler' should be renamed to 'assets_bundler'"
        end
      rescue => e
        # Ignore read errors as config file check already handles missing file
      end

      def check_version_consistency
        return unless package_json_exists?

        # Check if shakapacker npm package version matches gem version
        package_json = read_package_json
        npm_version = package_json.dig("dependencies", "shakapacker") ||
                     package_json.dig("devDependencies", "shakapacker")

        if npm_version
          gem_version = Shakapacker::VERSION rescue nil
          if gem_version && !versions_compatible?(gem_version, npm_version)
            @warnings << "Version mismatch: shakapacker gem is #{gem_version} but npm package is #{npm_version}"
          end
        end

        # Check if ensure_consistent_versioning is enabled and warn if versions might mismatch
        if config.ensure_consistent_versioning?
          @info << "Version consistency checking is enabled"
        end
      end

      def check_environment_consistency
        rails_env = defined?(Rails) ? Rails.env : ENV["RAILS_ENV"]
        node_env = ENV["NODE_ENV"]

        if rails_env && node_env && rails_env != node_env
          @warnings << "Environment mismatch: Rails.env is '#{rails_env}' but NODE_ENV is '#{node_env}'"
        end

        # Check SHAKAPACKER_ASSET_HOST for production
        if rails_env == "production" && ENV["SHAKAPACKER_ASSET_HOST"].nil?
          @info << "SHAKAPACKER_ASSET_HOST not set - assets will be served from the application host"
        end
      end

      def check_sri_dependencies
        return unless config.data.dig(:integrity, :enabled)

        bundler = config.assets_bundler
        if bundler == "webpack"
          unless package_installed?("webpack-subresource-integrity")
            @issues << "SRI is enabled but 'webpack-subresource-integrity' is not installed"
          end
        end

        # Validate hash functions
        hash_functions = config.data.dig(:integrity, :hash_functions) || ["sha384"]
        invalid_functions = hash_functions - ["sha256", "sha384", "sha512"]
        unless invalid_functions.empty?
          @issues << "Invalid SRI hash functions: #{invalid_functions.join(', ')}"
        end
      end

      def check_peer_dependencies
        return unless package_json_exists?

        bundler = config.assets_bundler
        package_json = read_package_json
        all_deps = (package_json["dependencies"] || {}).merge(package_json["devDependencies"] || {})

        if bundler == "webpack"
          check_webpack_peer_deps(all_deps)
        elsif bundler == "rspack"
          check_rspack_peer_deps(all_deps)
        end

        # Check for conflicting installations
        if package_installed?("webpack") && package_installed?("@rspack/core")
          @warnings << "Both webpack and rspack are installed - ensure assets_bundler is set correctly"
        end
      end

      def check_webpack_peer_deps(deps)
        essential_webpack = {
          "webpack" => "^5.76.0",
          "webpack-cli" => "^4.9.2 || ^5.0.0"
        }

        essential_webpack.each do |package, version|
          unless deps[package]
            @issues << "Missing essential webpack dependency: #{package} (#{version})"
          end
        end
      end

      def check_rspack_peer_deps(deps)
        essential_rspack = {
          "@rspack/cli" => "^1.0.0",
          "@rspack/core" => "^1.0.0"
        }

        essential_rspack.each do |package, version|
          unless deps[package]
            @issues << "Missing essential rspack dependency: #{package} (#{version})"
          end
        end
      end

      def check_windows_platform
        if Gem.win_platform?
          @info << "Windows detected: You may need to run shakapacker scripts with 'ruby bin/shakapacker'"

          # Check for case sensitivity issues
          if File.exist?(root_path.join("App")) || File.exist?(root_path.join("APP"))
            @warnings << "Potential case sensitivity issue detected on Windows filesystem"
          end
        end
      end

      def check_assets_compilation
        manifest_path = config.manifest_path

        if manifest_path.exist?
          # Check if manifest is recent (within last 24 hours)
          manifest_age_hours = (Time.now - File.mtime(manifest_path)) / 3600

          if manifest_age_hours > 24
            @info << "Assets were last compiled #{manifest_age_hours.round} hours ago. Consider recompiling if you've made changes."
          end

          # Check if source files are newer than manifest
          source_files = Dir.glob(File.join(config.source_path, "**/*.{js,jsx,ts,tsx,css,scss,sass}"))
          if source_files.any?
            newest_source = source_files.map { |f| File.mtime(f) }.max
            if newest_source > File.mtime(manifest_path)
              @warnings << "Source files have been modified after last asset compilation. Run 'rails assets:precompile'"
            end
          end
        else
          rails_env = defined?(Rails) ? Rails.env : ENV["RAILS_ENV"]
          if rails_env == "production"
            @issues << "No compiled assets found (manifest.json missing). Run 'rails assets:precompile'"
          else
            @info << "Assets not yet compiled. Run 'rails assets:precompile' or start the dev server"
          end
        end
      end

      def check_legacy_webpacker_files
        legacy_files = [
          "config/webpacker.yml",
          "config/webpack/webpacker.yml",
          "bin/webpack",
          "bin/webpack-dev-server"
        ]

        legacy_files.each do |file|
          file_path = root_path.join(file)
          if file_path.exist?
            @warnings << "Legacy webpacker file found: #{file} - consider removing after migration"
          end
        end
      end

      def check_node_installation
        stdout, stderr, status = Open3.capture3("node", "--version")

        if status.success?
          node_version = stdout.strip
          # Check minimum Node version (14.0.0 for modern tooling)
          version_match = node_version.match(/v(\d+)\.(\d+)\.(\d+)/)
          if version_match
            major = version_match[1].to_i
            if major < 14
              @warnings << "Node.js version #{node_version} is outdated. Recommend upgrading to v14 or higher"
            end
          end
        else
          @issues << "Node.js command failed: #{stderr}"
        end
      rescue Errno::ENOENT
        @issues << "Node.js is not installed or not in PATH"
      rescue Errno::EACCES
        @issues << "Permission denied when checking Node.js version"
      rescue StandardError => e
        @warnings << "Unable to check Node.js version: #{e.message}"
      end

      def check_package_manager
        unless package_manager
          @issues << "No package manager lock file found (package-lock.json, yarn.lock, pnpm-lock.yaml, or bun.lockb)"
        end
      end

      def check_binstub
        binstub_path = root_path.join("bin/shakapacker")
        unless binstub_path.exist?
          @warnings << "Shakapacker binstub not found at bin/shakapacker. Run 'rails shakapacker:binstubs' to create it."
        end
      end

      def check_javascript_transpiler_dependencies
        transpiler = config.javascript_transpiler

        # Default to SWC for v9+ if not configured
        if transpiler.nil?
          @info << "No javascript_transpiler configured - defaulting to SWC (20x faster than Babel)"
          transpiler = "swc"
        end

        return if transpiler == "none"

        bundler = config.assets_bundler

        case transpiler
        when "babel"
          check_babel_dependencies
          check_babel_performance_suggestion
        when "swc"
          check_swc_dependencies(bundler)
        when "esbuild"
          check_esbuild_dependencies
        else
          # Generic check for other transpilers
          loader_name = "#{transpiler}-loader"
          unless package_installed?(loader_name)
            @issues << "Missing required dependency '#{loader_name}' for JavaScript transpiler '#{transpiler}'"
          end
        end

        check_transpiler_config_consistency
      end

      def check_babel_dependencies
        unless package_installed?("babel-loader")
          @issues << "Missing required dependency 'babel-loader' for JavaScript transpiler 'babel'"
        end
        unless package_installed?("@babel/core")
          @issues << "Missing required dependency '@babel/core' for Babel transpiler"
        end
        unless package_installed?("@babel/preset-env")
          @issues << "Missing required dependency '@babel/preset-env' for Babel transpiler"
        end
      end

      def check_babel_performance_suggestion
        @info << "Consider switching to SWC for 20x faster compilation. Set javascript_transpiler: 'swc' in shakapacker.yml"
      end

      def check_swc_dependencies(bundler)
        if bundler == "webpack"
          unless package_installed?("@swc/core")
            @issues << "Missing required dependency '@swc/core' for SWC transpiler"
          end
          unless package_installed?("swc-loader")
            @issues << "Missing required dependency 'swc-loader' for SWC with webpack"
          end
        elsif bundler == "rspack"
          # Rspack has built-in SWC support
          @info << "Rspack has built-in SWC support - no additional loaders needed"
          if package_installed?("swc-loader")
            @warnings << "swc-loader is not needed with Rspack (SWC is built-in) - consider removing it"
          end
        end
      end

      def check_esbuild_dependencies
        unless package_installed?("esbuild")
          @issues << "Missing required dependency 'esbuild' for esbuild transpiler"
        end
        unless package_installed?("esbuild-loader")
          @issues << "Missing required dependency 'esbuild-loader' for esbuild transpiler"
        end
      end

      def check_transpiler_config_consistency
        babel_configs = [
          root_path.join(".babelrc"),
          root_path.join(".babelrc.js"),
          root_path.join(".babelrc.json"),
          root_path.join("babel.config.js"),
          root_path.join("babel.config.json")
        ]

        babel_config_exists = babel_configs.any?(&:exist?)

        # Check if package.json has babel config
        if package_json_exists?
          package_json = read_package_json
          babel_config_exists ||= package_json.key?("babel")
        end

        transpiler = config.javascript_transpiler

        if babel_config_exists && transpiler != "babel"
          @warnings << "Babel configuration files found but javascript_transpiler is '#{transpiler}'. Consider removing Babel configs or setting javascript_transpiler: 'babel'"
        end

        # Check for redundant dependencies
        if transpiler == "swc" && package_installed?("babel-loader")
          @warnings << "Both SWC and Babel dependencies are installed. Consider removing Babel dependencies to reduce node_modules size"
        end

        if transpiler == "esbuild" && package_installed?("babel-loader")
          @warnings << "Both esbuild and Babel dependencies are installed. Consider removing Babel dependencies to reduce node_modules size"
        end

        # Check for SWC configuration conflicts
        if transpiler == "swc"
          check_swc_config_conflicts
        end
      end

      def check_swc_config_conflicts
        swcrc_path = root_path.join(".swcrc")
        swc_config_path = root_path.join("config/swc.config.js")

        if swcrc_path.exist?
          @warnings << "SWC configuration: .swcrc file detected. This file completely overrides Shakapacker's default SWC settings and may cause build failures. " \
                      "Please migrate to config/swc.config.js which properly merges with Shakapacker defaults. " \
                      "To migrate: Move your custom settings from .swcrc to config/swc.config.js (see docs for format). " \
                      "See: https://github.com/shakacode/shakapacker/blob/main/docs/using_swc_loader.md"
        end

        if swc_config_path.exist?
          @info << "SWC configuration: Using config/swc.config.js (recommended). This config is merged with Shakapacker's defaults."
        end
      end

      def check_css_dependencies
        check_dependency("css-loader", @issues, "CSS")
        check_dependency("style-loader", @issues, "CSS (style-loader)")
        check_optional_dependency("mini-css-extract-plugin", @warnings, "CSS extraction")
      end

      def check_css_modules_configuration
        # Check for CSS module files in the project
        return unless config_exists?

        source_path = config.source_path
        return unless source_path.exist?

        # Performance optimization: Just check if ANY CSS module file exists
        # Using .first with early return is much faster than globbing all files
        css_module_exists = Dir.glob(File.join(source_path, "**/*.module.{css,scss,sass}")).first
        return unless css_module_exists

        # Check webpack configuration for CSS modules settings
        webpack_config_paths = [
          root_path.join("config/webpack/webpack.config.js"),
          root_path.join("config/webpack/webpack.config.ts"),
          root_path.join("config/webpack/commonWebpackConfig.js"),
          root_path.join("config/webpack/commonWebpackConfig.ts")
        ]

        webpack_config_paths.each do |config_path|
          next unless config_path.exist?

          config_content = File.read(config_path)

          # Check for the invalid configuration: namedExport: true with exportLocalsConvention: 'camelCase'
          if config_content.match(/namedExport\s*:\s*true/) && config_content.match(/exportLocalsConvention\s*:\s*['"]camelCase['"]/)
            @issues << "CSS Modules: Invalid configuration detected in #{config_path.relative_path_from(root_path)}"
            @issues << "  Using exportLocalsConvention: 'camelCase' with namedExport: true will cause build errors"
            @issues << "  Change to 'camelCaseOnly' or 'dashesOnly'. See docs/v9_upgrade.md for details"
          end

          # Warn if CSS modules are used but no configuration is found
          if !config_content.match(/namedExport/) && !config_content.match(/exportLocalsConvention/)
            @info << "CSS module files found but no explicit CSS modules configuration detected"
            @info << "  v9 defaults: namedExport: true, exportLocalsConvention: 'camelCaseOnly'"
          end
        end

        # Check for common v8 to v9 migration issues
        check_css_modules_import_patterns
      rescue => e
        # Don't fail doctor if CSS modules check has issues
        @warnings << "Unable to validate CSS modules configuration: #{e.message}"
      end

      def check_css_modules_import_patterns
        # Look for JavaScript/TypeScript files that might have v8-style imports
        source_path = config.source_path

        # Use lazy evaluation with Enumerator to avoid loading all file paths into memory
        # Stop after checking 50 files or finding a match
        v8_pattern = /import\s+\w+\s+from\s+['"][^'"]*\.module\.(css|scss|sass)['"]/

        Dir.glob(File.join(source_path, "**/*.{js,jsx,ts,tsx}")).lazy.take(50).each do |file|
          # Read file and check for v8 pattern
          content = File.read(file)

          # Check for v8 default import pattern with .module.css
          if v8_pattern.match?(content)
            @warnings << "Potential v8-style CSS module imports detected (using default import)"
            @warnings << "  v9 uses named exports. Update to: import { className } from './styles.module.css'"
            @warnings << "  Or use: import * as styles from './styles.module.css' (TypeScript)"
            @warnings << "  See docs/v9_upgrade.md for migration guide"
            break  # Stop after finding first occurrence
          end
        end
      rescue => e
        # Don't fail doctor if import pattern check has issues
      end

      def check_bundler_dependencies
        bundler = config.assets_bundler
        case bundler
        when "webpack"
          check_dependency("webpack", @issues, "webpack")
          check_dependency("webpack-cli", @issues, "webpack CLI")
        when "rspack"
          check_dependency("@rspack/core", @issues, "Rspack")
          check_dependency("@rspack/cli", @issues, "Rspack CLI")
        end
      end

      def check_file_type_dependencies
        source_path = config.source_path
        return unless source_path.exist?

        check_typescript_dependencies if typescript_files_exist?
        check_sass_dependencies if sass_files_exist?
        check_less_dependencies if less_files_exist?
        check_stylus_dependencies if stylus_files_exist?
        check_postcss_dependencies if postcss_config_exists?
      end

      def check_typescript_dependencies
        transpiler = config.javascript_transpiler
        if transpiler == "babel"
          check_optional_dependency("@babel/preset-typescript", @warnings, "TypeScript with Babel")
        elsif transpiler != "esbuild" && transpiler != "swc"
          check_optional_dependency("ts-loader", @warnings, "TypeScript")
        end
      end

      def check_sass_dependencies
        check_dependency("sass-loader", @issues, "Sass/SCSS")
        check_dependency("sass", @issues, "Sass/SCSS (sass package)")
      end

      def check_less_dependencies
        check_dependency("less-loader", @issues, "Less")
        check_dependency("less", @issues, "Less (less package)")
      end

      def check_stylus_dependencies
        check_dependency("stylus-loader", @issues, "Stylus")
        check_dependency("stylus", @issues, "Stylus (stylus package)")
      end

      def check_postcss_dependencies
        check_dependency("postcss", @issues, "PostCSS")
        check_dependency("postcss-loader", @issues, "PostCSS")
      end

      def check_dependency(package_name, issues_array, description)
        unless package_installed?(package_name)
          issues_array << "Missing required dependency '#{package_name}' for #{description}"
        end
      end

      def check_optional_dependency(package_name, warnings_array, description)
        unless package_installed?(package_name)
          warnings_array << "Optional dependency '#{package_name}' for #{description} is not installed"
        end
      end

      def package_installed?(package_name)
        return false unless package_json_exists?

        package_json = read_package_json
        dependencies = (package_json["dependencies"] || {}).merge(package_json["devDependencies"] || {})
        dependencies.key?(package_name)
      end

      def package_json_exists?
        package_json_path.exist?
      end

      def package_json_path
        root_path.join("package.json")
      end

      def read_package_json
        @package_json ||= begin
          JSON.parse(File.read(package_json_path))
        rescue JSON::ParserError
          {}
        end
      end

      def config_exists?
        config.config_path.exist?
      end

      def typescript_files_exist?
        # Use .first for early exit optimization
        !Dir.glob(File.join(config.source_path, "**/*.{ts,tsx}")).first.nil?
      end

      def sass_files_exist?
        !Dir.glob(File.join(config.source_path, "**/*.{sass,scss}")).first.nil?
      end

      def less_files_exist?
        !Dir.glob(File.join(config.source_path, "**/*.less")).first.nil?
      end

      def stylus_files_exist?
        !Dir.glob(File.join(config.source_path, "**/*.{styl,stylus}")).first.nil?
      end

      def postcss_config_exists?
        root_path.join("postcss.config.js").exist?
      end

      def package_manager
        @package_manager ||= detect_package_manager
      end

      def detect_package_manager
        return "bun" if File.exist?(root_path.join("bun.lockb"))
        return "pnpm" if File.exist?(root_path.join("pnpm-lock.yaml"))
        return "yarn" if File.exist?(root_path.join("yarn.lock"))
        return "npm" if File.exist?(root_path.join("package-lock.json"))
        nil
      end

      def versions_compatible?(gem_version, npm_version)
        # Handle pre-release versions and ranges properly
        npm_clean = npm_version.gsub(/[\^~]/, "")

        # Extract version without pre-release suffix
        gem_base = gem_version.split("-").first
        npm_base = npm_clean.split("-").first

        # Compare major versions
        gem_major = gem_base.split(".").first
        npm_major = npm_base.split(".").first

        if gem_major != npm_major
          return false
        end

        # For same major version, check if npm version satisfies gem version
        begin
          # Use semantic versioning if available
          if defined?(SemanticRange)
            SemanticRange.satisfies?(gem_version, npm_version)
          else
            gem_major == npm_major
          end
        rescue StandardError
          # Fallback to simple major version comparison
          gem_major == npm_major
        end
      end

      def report_results
        reporter = Reporter.new(self)
        reporter.print_report
        exit(1) unless success?
      end

      class Reporter
        attr_reader :doctor

        def initialize(doctor)
          @doctor = doctor
        end

        def print_report
          print_header
          print_checks
          print_summary
        end

        private

          def print_header
            puts "Running Shakapacker doctor..."
            puts "=" * 60
          end

          def print_checks
            if doctor.config.config_path.exist?
              puts "✓ Configuration file found"
              print_transpiler_status
              print_bundler_status
              print_css_status
            end

            print_node_status
            print_package_manager_status
            print_binstub_status
            print_info_messages
          end

          def print_transpiler_status
            transpiler = doctor.config.javascript_transpiler
            return if transpiler.nil? || transpiler == "none"

            loader_name = "#{transpiler}-loader"
            if doctor.send(:package_installed?, loader_name)
              puts "✓ JavaScript transpiler: #{loader_name} is installed"
            end
          end

          def print_bundler_status
            bundler = doctor.config.assets_bundler
            case bundler
            when "webpack"
              print_package_status("webpack", "webpack")
              print_package_status("webpack-cli", "webpack CLI")
            when "rspack"
              print_package_status("@rspack/core", "Rspack")
              print_package_status("@rspack/cli", "Rspack CLI")
            end
          end

          def print_css_status
            print_package_status("css-loader", "CSS")
            print_package_status("style-loader", "CSS (style-loader)")
            print_package_status("mini-css-extract-plugin", "CSS extraction (optional)")
          end

          def print_package_status(package_name, description)
            if doctor.send(:package_installed?, package_name)
              puts "✓ #{description}: #{package_name} is installed"
            end
          end

          def print_node_status
            begin
              stdout, stderr, status = Open3.capture3("node", "--version")
              if status.success?
                puts "✓ Node.js #{stdout.strip} found"
              end
            rescue Errno::ENOENT, Errno::EACCES, StandardError
              # Error already added to issues
            end
          end

          def print_package_manager_status
            package_manager = doctor.send(:package_manager)
            if package_manager
              puts "✓ Package manager: #{package_manager}"
            end
          end

          def print_binstub_status
            binstub_path = doctor.root_path.join("bin/shakapacker")
            if binstub_path.exist?
              puts "✓ Shakapacker binstub found"
            end
          end

          def print_info_messages
            return if doctor.info.empty?

            puts "\nℹ️  Information:"
            doctor.info.each do |info|
              puts "  • #{info}"
            end
          end

          def print_summary
            puts "=" * 60

            if doctor.issues.empty? && doctor.warnings.empty?
              puts "✅ No issues found! Shakapacker appears to be configured correctly."
            else
              print_issues if doctor.issues.any?
              print_warnings if doctor.warnings.any?
              print_fix_instructions
            end
          end

          def print_issues
            puts "❌ Issues found (#{doctor.issues.length}):"
            doctor.issues.each_with_index do |issue, index|
              puts "  #{index + 1}. #{issue}"
            end
            puts ""
          end

          def print_warnings
            puts "⚠️  Warnings (#{doctor.warnings.length}):"
            doctor.warnings.each_with_index do |warning, index|
              puts "  #{index + 1}. #{warning}"
            end
            puts ""
          end

          def print_fix_instructions
            package_manager = doctor.send(:package_manager)
            puts "To fix missing dependencies, run:"
            puts "  #{package_manager_install_command(package_manager)}"
          end

          def package_manager_install_command(manager)
            case manager
            when "bun" then "bun add -D [package-name]"
            when "pnpm" then "pnpm add -D [package-name]"
            when "yarn" then "yarn add -D [package-name]"
            when "npm" then "npm install --save-dev [package-name]"
            else "npm install --save-dev [package-name]"
            end
          end
      end
  end
end

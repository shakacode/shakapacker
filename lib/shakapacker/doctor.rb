require "json"
require "pathname"
require "open3"
require "semantic_range"

module Shakapacker
  class Doctor
    attr_reader :config, :root_path, :issues, :warnings, :info, :options

    # Warning categories for better organization
    CATEGORY_ACTION_REQUIRED = :action_required
    CATEGORY_RECOMMENDED = :recommended
    CATEGORY_INFO = :info

    REQUIRED_BINSTUBS = {
      "bin/shakapacker" => "Main Shakapacker binstub",
      "bin/shakapacker-dev-server" => "Development server binstub",
      "bin/shakapacker-config" => "Config export binstub"
    }.freeze

    OPTIONAL_BINSTUBS = %w[
      bin/shakapacker-watch
      bin/diff-bundler-config
    ].freeze

    PACKAGE_MANAGER_LOCKFILES = {
      "bun.lockb" => "bun",
      "pnpm-lock.yaml" => "pnpm",
      "yarn.lock" => "yarn",
      "package-lock.json" => "npm"
    }.freeze

    SASS_IMPLEMENTATION_PACKAGES = %w[
      sass
      sass-embedded
    ].freeze

    SASS_IMPLEMENTATION_DEPENDENCY_MESSAGE = (
      "Missing required dependency 'sass' or 'sass-embedded' " \
      "for Sass/SCSS implementation"
    ).freeze

    REQUIRED_RSPACK_DEPS = {
      "@rspack/core" => "^2.0.0",
      "@rspack/cli" => "^2.0.0",
      "rspack-manifest-plugin" => "^5.2.2"
    }.freeze

    RSPACK_DEV_SERVER_DEP = {
      "@rspack/dev-server" => "^2.0.0"
    }.freeze

    RSPACK_V2_ONLY_DEPS = REQUIRED_RSPACK_DEPS
      .slice("@rspack/core", "@rspack/cli")
      .merge(RSPACK_DEV_SERVER_DEP)
      .freeze

    OPTIONAL_RSPACK_V2_ONLY_DEPS = {
      "@rspack/plugin-react-refresh" => "^2.0.0"
    }.freeze

    RSPACK_REACT_REFRESH_PACKAGE = "@rspack/plugin-react-refresh".freeze
    VERSION_UPPER_BOUND_OPERATORS = %w[< <=].freeze

    CUSTOM_HYBRID_LOADER_DEPS = %w[
      babel-loader
      esbuild-loader
      ts-loader
    ].freeze

    BUNDLER_CONFIG_EXTENSIONS = %w[
      ts
      js
    ].freeze

    PACKAGE_ROOT_MARKERS = (["package.json"] + PACKAGE_MANAGER_LOCKFILES.keys + ["node_modules"]).freeze

    def initialize(config = nil, root_path = nil, options = {})
      @config = config || Shakapacker.config
      @root_path = root_path || (defined?(Rails) ? Rails.root : Pathname.new(Dir.pwd))
      @issues = []
      @warnings = []  # Now stores hashes: { category: :symbol, message: "..." }
      @info = []
      @options = options
    end

    def run
      if options[:help]
        print_help
        return
      end

      perform_checks
      report_results
    end

    def success?
      @issues.empty?
    end

    private

      def add_warning(message, category = CATEGORY_RECOMMENDED)
        @warnings << { category: category, message: message }
      end

      def add_action_required(message)
        add_warning(message, CATEGORY_ACTION_REQUIRED)
      end

      def add_info_warning(message)
        add_warning(message, CATEGORY_INFO)
      end

      # Marks the warning as a Fix sub-item; the renderer owns the "Fix: " prefix and indentation.
      # The stored category mirrors the parent warning so a fix attached to an action-required
      # item is itself action-required (it's only rendered alongside its parent, but the data
      # stays consistent for any downstream consumer).
      def add_fix_hint(message)
        parent = @warnings.reverse_each.find { |w| !w[:fix] }
        category = parent ? parent[:category] : CATEGORY_RECOMMENDED
        @warnings << { category: category, message: message, fix: true }
      end

      def print_help
        puts <<~HELP
          Shakapacker Doctor - Diagnostic tool for Shakapacker configuration

          Usage:
            bundle exec rake shakapacker:doctor [options]

          Options:
            --help       Show this help message
            --verbose    Show detailed information about all checks

          Description:
            The doctor command checks for common configuration issues and missing
            dependencies in your Shakapacker setup, including:

            • Configuration file validity
            • Entry points and output paths
            • Node.js and package manager installation
            • Required npm dependencies
            • JavaScript transpiler configuration
            • CSS and CSS Modules setup
            • Binstubs presence
            • Version consistency
            • Legacy file detection

          Exit codes:
            0 - No issues found
            1 - Issues detected (see output for details)
        HELP
      end

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
        check_rspack_cache_configuration if config_exists?
        check_rspack_react_refresh_plugin_constructor if config_exists?
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
        report_empty_assets_bundler_env_override if empty_assets_bundler_env_override?

        unless config.config_path.exist?
          @issues << "Configuration file not found at #{config.config_path}"
        end
      end

      def check_entry_points
        # Check for invalid configuration first
        if config.fetch(:source_entry_path) == "/" && config.nested_entries?
          @issues << "Invalid configuration: cannot use '/' as source_entry_path with nested_entries: true"
          return  # Don't try to check files when config is invalid
        end

        source_entry_path = config.source_path.join(config.fetch(:source_entry_path) || "packs")

        unless source_entry_path.exist?
          @issues << "Source entry path #{source_entry_path} does not exist"
          return
        end

        # Check for at least one entry point
        entry_files = Dir.glob(File.join(source_entry_path, "**/*.{js,jsx,ts,tsx,coffee}"))
        if entry_files.empty?
          add_warning("No entry point files found in #{source_entry_path}")
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
              add_warning("Manifest file is empty - you may need to run 'bundle exec rake assets:precompile'")
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
        config_relative_path = config.config_path.relative_path_from(root_path)

        if config_file.include?("webpack_loader:")
          add_action_required("Deprecated config: 'webpack_loader' should be renamed to 'javascript_transpiler' in #{config_relative_path}")
        end

        # Check for standalone "bundler:" but not "assets_bundler:"
        # Match "bundler:" at start of line or preceded by non-underscore character
        if config_file.match?(/^\s*bundler:/m) || config_file.match?(/[^_]bundler:/)
          add_action_required("Deprecated config: 'bundler' should be renamed to 'assets_bundler' in #{config_relative_path}.")
          add_fix_hint("Open #{config_relative_path} and change 'bundler:' to 'assets_bundler:'.")
        end
      rescue => e
        # Ignore read errors as config file check already handles missing file
      end

      def check_version_consistency
        return unless package_json_exists?

        # Check if shakapacker npm package version matches gem version. Use the
        # flattened dependency map so a nearer package root wins across sections.
        npm_version = package_json_dependency_version("shakapacker")

        if npm_version
          # Skip version check for github/file references
          return if npm_version.start_with?("github:", "git+", "file:", "link:", "./", "../", "/")

          gem_version = Shakapacker::VERSION rescue nil
          if gem_version && !versions_compatible?(gem_version, npm_version)
            add_info_warning("Version mismatch: shakapacker gem is #{gem_version} but npm package is #{npm_version}")
          end
        end

        # Check if ensure_consistent_versioning is enabled
        if config.ensure_consistent_versioning?
          @info << "Version consistency checking: enabled (ensures shakapacker gem and npm package versions match at runtime)"
        end
      end

      def check_environment_consistency
        rails_env = defined?(Rails) ? Rails.env : ENV["RAILS_ENV"]
        node_env = ENV["NODE_ENV"]

        if rails_env && node_env && rails_env != node_env
          add_warning("Environment mismatch: Rails.env is '#{rails_env}' but NODE_ENV is '#{node_env}'")
        end

        # Check SHAKAPACKER_ASSET_HOST for production
        if rails_env == "production" && ENV["SHAKAPACKER_ASSET_HOST"].nil?
          @info << "SHAKAPACKER_ASSET_HOST not set - assets will be served from the application host"
        end
      end

      def check_sri_dependencies
        integrity_config = config.integrity
        return unless integrity_config&.dig(:enabled)

        bundler = assets_bundler
        if bundler == "webpack"
          unless package_installed?("webpack-subresource-integrity")
            @issues << "SRI is enabled but 'webpack-subresource-integrity' is not installed"
          end
        end

        # Validate hash functions
        hash_functions = integrity_config.dig(:hash_functions) || ["sha384"]
        invalid_functions = hash_functions - ["sha256", "sha384", "sha512"]
        unless invalid_functions.empty?
          @issues << "Invalid SRI hash functions: #{invalid_functions.join(', ')}"
        end
      end

      def check_peer_dependencies
        return unless package_json_exists?

        bundler = assets_bundler
        all_deps = declared_package_dependencies

        if bundler == "webpack"
          check_webpack_peer_deps(all_deps)
        elsif bundler == "rspack"
          check_rspack_peer_deps(all_deps)
        end

        # Check for conflicting installations
        if package_installed?("webpack") && package_installed?("@rspack/core")
          if assets_bundler_configured?
            add_warning("Both webpack and rspack are installed - ensure assets_bundler is set correctly")
          else
            add_warning("Both webpack and rspack are installed while assets_bundler is inferred as '#{bundler}'. " \
                        "This can be intentional for custom hybrid webpack/Rspack setups; set assets_bundler " \
                        "explicitly to document the active Shakapacker-managed bundler.")
          end
        end
      end

      def check_webpack_peer_deps(deps)
        essential_webpack = {
          "webpack" => "^5.101.0",
          "webpack-cli" => "^4.9.2 || ^5.0.0 || ^6.0.0 || ^7.0.0"
        }

        essential_webpack.each do |package, version|
          unless deps[package]
            @issues << "Missing essential webpack dependency: #{package} (#{version})"
          end
        end
      end

      def check_rspack_peer_deps(deps)
        REQUIRED_RSPACK_DEPS.each do |package, version|
          unless deps[package] || installed_package_version(package)
            @issues << "Missing essential rspack dependency: #{package} (#{version})"
          end
        end

        RSPACK_DEV_SERVER_DEP.each do |package, version|
          unless deps[package] || installed_package_version(package)
            add_warning("Missing recommended rspack dependency: #{package} (#{version}) for Rspack dev server")
          end
        end

        unsupported_packages = RSPACK_V2_ONLY_DEPS.keys.select do |package|
          deps[package] &&
          (rspack_major_version_for(package) == 1 || rspack_declared_major_version_for(package) == 1)
        end

        if unsupported_packages.any?
          @issues << "Unsupported rspack dependency version: Shakapacker supports Rspack v2 only. " \
                     "Upgrade #{unsupported_packages.join(' and ')} to ^2.0.0."
        end

        unsupported_optional_packages = OPTIONAL_RSPACK_V2_ONLY_DEPS.keys.select do |package|
          deps[package] &&
          (rspack_major_version_for(package) == 1 || rspack_declared_major_version_for(package) == 1)
        end

        if unsupported_optional_packages.any?
          add_warning("Unsupported optional rspack dependency version: Shakapacker supports Rspack v2 only. " \
                      "Upgrade #{unsupported_optional_packages.join(' and ')} to ^2.0.0.")
        end

        manifest_status = package_version_status("rspack-manifest-plugin", "5.2.2")
        if deps["rspack-manifest-plugin"] && manifest_status[:installed_below]
          @issues << "Unsupported rspack-manifest-plugin version: Shakapacker requires rspack-manifest-plugin " \
                     "^5.2.2 for Rspack v2."
        end

        if deps["rspack-manifest-plugin"] && manifest_status[:declared_below]
          @issues << "Declared rspack-manifest-plugin range allows unsupported versions. " \
                     "Update package.json to require rspack-manifest-plugin ^5.2.2 for Rspack v2."
        end
      end

      def check_windows_platform
        if Gem.win_platform?
          @info << "Windows detected: You may need to run shakapacker scripts with 'ruby bin/shakapacker'"

          # Check for case sensitivity issues
          if File.exist?(root_path.join("App")) || File.exist?(root_path.join("APP"))
            add_warning("Potential case sensitivity issue detected on Windows filesystem")
          end
        end
      end

      def check_assets_compilation
        manifest_path = config.manifest_path

        if manifest_path.exist?
          # Check if manifest is recent (within last 24 hours)
          manifest_age_hours = (Time.now - File.mtime(manifest_path)) / 3600

          if manifest_age_hours > 24 && options[:verbose]
            # Only show age in verbose mode - it's not actionable information
            @info << "Assets were last compiled #{manifest_age_hours.round} hours ago. Consider recompiling if you've made changes."
          end

          # Check if source files are newer than manifest
          source_files = Dir.glob(File.join(config.source_path, "**/*.{js,jsx,ts,tsx,css,scss,sass}"))
          if source_files.any?
            newest_source = source_files.map { |f| File.mtime(f) }.max
            if newest_source > File.mtime(manifest_path)
              add_warning("Source files have been modified after last asset compilation. Run 'bundle exec rake assets:precompile'")
            end
          end
        else
          rails_env = defined?(Rails) ? Rails.env : ENV["RAILS_ENV"]
          if rails_env == "production"
            @issues << "No compiled assets found (manifest.json missing). Run 'bundle exec rake assets:precompile'"
          elsif options[:verbose]
            # Only show in verbose mode for non-production environments
            @info << "Assets not yet compiled. Run 'bundle exec rake assets:precompile' or start the dev server"
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
            add_warning("Legacy webpacker file found: #{file} - consider removing after migration")
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
              add_warning("Node.js version #{node_version} is outdated. Recommend upgrading to v14 or higher")
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
        add_warning("Unable to check Node.js version: #{e.message}")
      end

      def check_package_manager
        unless package_manager
          @issues << "No package manager lock file found (package-lock.json, yarn.lock, pnpm-lock.yaml, or bun.lockb)"
        end
      end

      def check_binstub
        missing_binstubs = []

        REQUIRED_BINSTUBS.each do |path, description|
          unless root_path.join(path).exist?
            missing_binstubs << "#{path} (#{description})"
          end
        end

        unless missing_binstubs.empty?
          add_action_required("Missing binstubs: #{missing_binstubs.join(', ')}.")
          add_fix_hint("Run 'bundle exec rake shakapacker:binstubs' to create them.")
        end
      end

      def check_javascript_transpiler_dependencies
        transpiler = explicit_javascript_transpiler
        implicit_babel_fallback = false

        if transpiler.nil?
          transpiler = javascript_transpiler
          implicit_babel_fallback = transpiler == "babel"
        end

        @resolved_javascript_transpiler = transpiler
        return if transpiler == "none"

        bundler = assets_bundler
        unconfigured_hybrid_graph = unconfigured_hybrid_loader_graph?
        inferred_hybrid_graph = inferred_hybrid_loader_graph?(
          transpiler,
          bundler,
          unconfigured_hybrid_graph: unconfigured_hybrid_graph
        )
        if inferred_hybrid_graph
          add_info_warning("Detected a custom hybrid webpack/Rspack setup while Doctor inferred webpack/SWC. " \
                           "Skipping SWC dependency issue checks for this inferred default. For custom hybrid webpack/Rspack configs, " \
                           "set javascript_transpiler: \"none\" when Shakapacker should not validate loader dependencies, " \
                           "or set javascript_transpiler/assets_bundler explicitly when Shakapacker owns that build path.")
        elsif unconfigured_hybrid_graph
          add_info_warning("Detected a custom hybrid webpack/Rspack setup with inferred Shakapacker defaults. " \
                           "Doctor is validating the active #{bundler}/#{transpiler} default only. " \
                           "Set javascript_transpiler: \"none\" when Shakapacker should not validate loader dependencies, " \
                           "or set javascript_transpiler/assets_bundler explicitly when Shakapacker owns that build path.")
        end

        case transpiler
        when "babel"
          check_babel_dependencies
          check_babel_performance_suggestion unless implicit_babel_fallback
        when "swc"
          check_swc_dependencies(bundler) unless inferred_hybrid_graph
        when "esbuild"
          check_esbuild_dependencies
        else
          # Generic check for other transpilers
          loader_name = "#{transpiler}-loader"
          unless package_installed?(loader_name)
            @issues << "Missing required dependency '#{loader_name}' for JavaScript transpiler '#{transpiler}'"
          end
        end

        check_transpiler_config_consistency(transpiler, inferred_hybrid_graph: inferred_hybrid_graph)
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

      def implicit_javascript_transpiler
        if assets_bundler == "webpack" && !package_installed?("swc-loader") && package_installed?("babel-loader")
          @info << "`javascript_transpiler` is not set in config/shakapacker.yml. " \
                   "Shakapacker defaults to SWC, but swc-loader is not installed and Babel was detected, so Babel will be used. " \
                   "Set `javascript_transpiler: babel` (or `swc`) explicitly to silence this message. " \
                   "See https://github.com/shakacode/shakapacker/blob/main/docs/transpiler-migration.md"
          "babel"
        else
          @info << "No javascript_transpiler configured - using bundled SWC default. " \
                   "Set javascript_transpiler: 'swc' or 'babel' explicitly in shakapacker.yml to silence this message."
          "swc"
        end
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
            package_manager = detect_package_manager
            remove_cmd = case package_manager
                         when "yarn" then "yarn remove swc-loader"
                         when "npm" then "npm uninstall swc-loader"
                         when "pnpm" then "pnpm remove swc-loader"
                         when "bun" then "bun remove swc-loader"
                        else "npm uninstall swc-loader"
            end
            add_warning("swc-loader is not needed with Rspack (SWC is built-in). Rspack includes SWC transpilation natively, so this package is redundant.")
            add_fix_hint("Remove it with: #{remove_cmd}.")
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

      def check_transpiler_config_consistency(transpiler = javascript_transpiler, inferred_hybrid_graph: nil)
        inferred_hybrid_graph = inferred_hybrid_loader_graph?(transpiler, assets_bundler) if inferred_hybrid_graph.nil?

        babel_configs = [
          root_path.join(".babelrc"),
          root_path.join(".babelrc.js"),
          root_path.join(".babelrc.json"),
          root_path.join("babel.config.js"),
          root_path.join("babel.config.json")
        ]

        babel_config_exists = babel_configs.any?(&:exist?)
        babel_in_package_json = false

        # Check if package.json has babel config
        if package_json_exists?
          babel_in_package_json = package_json_key?("babel")
          babel_config_exists ||= babel_in_package_json
        end

        if babel_config_exists && transpiler != "babel" && !inferred_hybrid_graph
          babel_files = babel_configs.select(&:exist?).map { |f| f.relative_path_from(root_path) }
          babel_files << "package.json" if babel_in_package_json
          babel_files_str = babel_files.join(", ")
          add_warning("Babel configuration files found (#{babel_files_str}) but javascript_transpiler is '#{transpiler}'. These Babel configs are ignored by Shakapacker (though they may still be used by ESLint or other tools).")
          add_fix_hint("Remove Babel config files if not needed, or set javascript_transpiler: 'babel' in shakapacker.yml to use Babel for transpilation.")
        end

        # Check for redundant dependencies
        if transpiler == "swc" && package_installed?("babel-loader") && !inferred_hybrid_graph
          add_warning("Both SWC and Babel dependencies are installed. Consider removing Babel dependencies to reduce node_modules size")
        end

        if transpiler == "esbuild" && package_installed?("babel-loader")
          add_warning("Both esbuild and Babel dependencies are installed. Consider removing Babel dependencies to reduce node_modules size")
        end

        # Check for SWC configuration conflicts
        if transpiler == "swc"
          check_swc_config_conflicts
        end
      end

      def inferred_hybrid_loader_graph?(transpiler, bundler, unconfigured_hybrid_graph: nil)
        unconfigured_hybrid_graph = unconfigured_hybrid_loader_graph? if unconfigured_hybrid_graph.nil?

        transpiler == "swc" &&
          bundler == "webpack" &&
          unconfigured_hybrid_graph
      end

      def unconfigured_hybrid_loader_graph?
        !javascript_transpiler_configured? &&
          !assets_bundler_configured? &&
          package_installed?("webpack") &&
          package_installed?("@rspack/core") &&
          inferred_hybrid_bundler_config_present? &&
          custom_hybrid_loader_dependency?
      end

      def inferred_hybrid_bundler_config_present?
        same_directory_hybrid_config_present?(config.assets_bundler_config_path.to_s) ||
          default_split_hybrid_config_present?
      end

      def same_directory_hybrid_config_present?(directory)
        bundler_config_present?(directory, "webpack") &&
          bundler_config_present?(directory, "rspack")
      end

      def default_split_hybrid_config_present?
        bundler_config_present?("config/webpack", "webpack") &&
          (bundler_config_present?("config/rspack", "rspack") ||
            bundler_config_present?("config/rspack", "webpack"))
      end

      def bundler_config_present?(directory, basename)
        BUNDLER_CONFIG_EXTENSIONS.any? do |extension|
          Pathname.new(File.join(root_path.to_s, directory.to_s, "#{basename}.config.#{extension}")).exist?
        end
      end

      def custom_hybrid_loader_dependency?
        CUSTOM_HYBRID_LOADER_DEPS.any? { |package_name| package_installed?(package_name) }
      end

      def check_swc_config_conflicts
        swcrc_path = root_path.join(".swcrc")
        swc_config_path = root_path.join("config/swc.config.js")

        if swcrc_path.exist?
          add_warning("SWC configuration: .swcrc file detected. This file completely overrides Shakapacker's default SWC settings and may cause build failures. " \
                      "Please migrate to config/swc.config.js which properly merges with Shakapacker defaults. " \
                      "To migrate: Move your custom settings from .swcrc to config/swc.config.js (see docs for format). " \
                      "See: https://github.com/shakacode/shakapacker/blob/main/docs/using_swc_loader.md")
        end

        if swc_config_path.exist?
          @info << "SWC configuration: Using config/swc.config.js (recommended). This config is merged with Shakapacker's defaults."
          check_swc_config_settings(swc_config_path)
        end
      end

      def check_swc_config_settings(config_path)
        config_content = File.read(config_path, encoding: "UTF-8")

        # Check for loose: true (deprecated default)
        if config_content.match?(/loose\s*:\s*true/)
          add_warning("SWC configuration: 'loose: true' detected in config/swc.config.js. " \
                      "This can cause silent failures with Stimulus controllers and incorrect spread operator behavior. " \
                      "Consider removing this setting to use Shakapacker's default 'loose: false' (spec-compliant). " \
                      "See: https://github.com/shakacode/shakapacker/blob/main/docs/using_swc_loader.md#using-swc-with-stimulus")
        end

        # Check for missing keepClassNames with Stimulus
        if stimulus_likely_used? && !config_content.match?(/keepClassNames\s*:\s*true/)
          add_warning("SWC configuration: Stimulus appears to be in use, but 'keepClassNames: true' is not set in config/swc.config.js. " \
                      "Without this setting, Stimulus controllers will fail silently. " \
                      "Add 'keepClassNames: true' to jsc config. " \
                      "See: https://github.com/shakacode/shakapacker/blob/main/docs/using_swc_loader.md#using-swc-with-stimulus")
        elsif config_content.match?(/keepClassNames\s*:\s*true/)
          @info << "SWC configuration: 'keepClassNames: true' is set (good for Stimulus compatibility)"
        end

        # Check for jsc.target and env conflict
        # Use word boundary to avoid false positives with transform.target or other nested properties
        if config_content.match?(/jsc\s*:\s*\{[^}]*\btarget\s*:/) && config_content.match?(/env\s*:\s*\{/)
          @issues << "SWC configuration: Both 'jsc.target' and 'env' are configured. These cannot be used together. " \
                     "Remove 'jsc.target' and use only 'env' (Shakapacker sets this automatically). " \
                     "See: https://github.com/shakacode/shakapacker/blob/main/docs/using_swc_loader.md#using-swc-with-stimulus"
        end
      rescue => e
        # Don't fail doctor if SWC config check has issues
        add_warning("Unable to validate SWC configuration: #{e.message}")
      end

      def stimulus_likely_used?
        return false unless package_json_exists?

        # Check for @hotwired/stimulus or stimulus package
        declared_package_dependencies.key?("@hotwired/stimulus") ||
          declared_package_dependencies.key?("stimulus")
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
        end

        # Check for common v8 to v9 migration issues
        check_css_modules_import_patterns
      rescue => e
        # Don't fail doctor if CSS modules check has issues
        add_warning("Unable to validate CSS modules configuration: #{e.message}")
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
            add_warning("Potential v8-style CSS module imports detected (using default import)")
            add_warning("  v9 uses named exports. Update to: import { className } from './styles.module.css'")
            add_warning("  Or use: import * as styles from './styles.module.css' (TypeScript)")
            add_warning("  See docs/v9_upgrade.md for migration guide")
            break  # Stop after finding first occurrence
          end
        end
      rescue => e
        # Don't fail doctor if import pattern check has issues
      end

      def check_bundler_dependencies
        bundler = assets_bundler
        case bundler
        when "webpack"
          check_dependency("webpack", @issues, "webpack")
          check_dependency("webpack-cli", @issues, "webpack CLI")
        when "rspack"
          check_dependency("@rspack/core", @issues, "Rspack")
          check_dependency("@rspack/cli", @issues, "Rspack CLI")
        end
      end

      def check_rspack_cache_configuration
        return unless config.rspack?

        rspack_major = rspack_major_version

        if rspack_major == 1
          add_warning("Rspack v1 detected: Shakapacker supports Rspack v2 only. " \
                      "Upgrade to Rspack v2 for supported builds and stable persistent caching.")
          add_fix_hint("Bump @rspack/core and @rspack/cli to ^2.0.0 in package.json. See https://rspack.rs/config/cache and docs/rspack.md for details.")
        end

        path = active_assets_bundler_config_path
        return unless path

        content = read_active_assets_bundler_config(path)
        return unless content

        return unless rspack_cache_disabled?(content)

        relative = config_path_for_warning(path)
        add_warning("Rspack cache appears to be disabled in #{relative} (found 'cache: false'). Disabling cache " \
                    "causes significantly slower builds, especially on rebuilds. Rspack v2 promotes filesystem " \
                    "caching from experimental to stable.")
        add_fix_hint("Remove the 'cache: false' setting, or use 'cache: { type: \"filesystem\" }' for persistent caching. " \
                     "See https://rspack.rs/config/cache for options.")
      end

      def check_rspack_react_refresh_plugin_constructor
        return unless rspack_react_refresh_check_applicable?
        return unless rspack_react_refresh_plugin_v2_or_newer?

        rspack_react_refresh_config_paths.each do |path|
          content = File.read(path)
          next unless legacy_rspack_react_refresh_constructor?(content)

          relative = config_path_for_warning(path)
          add_action_required("Rspack React Refresh config #{relative} uses the " \
                              "#{RSPACK_REACT_REFRESH_PACKAGE} v1 default-export constructor pattern. " \
                              "With #{RSPACK_REACT_REFRESH_PACKAGE} v2, rspack may fail with " \
                              "'ReactRefreshPlugin is not a constructor'.")
          add_fix_hint("Use a compat constructor: const ReactRefresh = require(\"#{RSPACK_REACT_REFRESH_PACKAGE}\"); " \
                       "const ReactRefreshRspackPlugin = ReactRefresh.ReactRefreshRspackPlugin || " \
                       "ReactRefresh.default || ReactRefresh; then call new ReactRefreshRspackPlugin().")
        rescue SystemCallError => e
          add_info_warning("Unable to validate Rspack React Refresh config #{config_path_for_warning(path)}: #{e.message}")
        end
      end

      def rspack_react_refresh_check_applicable?
        assets_bundler == "rspack" || unconfigured_hybrid_loader_graph?
      end

      def rspack_react_refresh_plugin_v2_or_newer?
        version = installed_package_version(RSPACK_REACT_REFRESH_PACKAGE)
        return version >= Gem::Version.new("2.0.0") if version

        package_specifier_allows_version_or_newer?(
          package_json_dependency_version(RSPACK_REACT_REFRESH_PACKAGE),
          Gem::Version.new("2.0.0")
        )
      end

      def rspack_react_refresh_config_paths
        config_dir = rspack_react_refresh_config_dir
        config_dir_path = Pathname.new(File.join(root_path.to_s, config_dir))
        return [] unless config_dir_path.directory?

        path = active_bundler_config_path_in(config_dir)
        path ? [path] : []
      end

      def rspack_react_refresh_config_dir
        config_dir = config.assets_bundler_config_path.to_s

        if assets_bundler == "rspack" || same_directory_hybrid_config_present?(config_dir)
          config_dir
        else
          "config/rspack"
        end
      end

      def legacy_rspack_react_refresh_constructor?(content)
        stripped = strip_rspack_config_comments_and_literals(content, preserve_literals: [RSPACK_REACT_REFRESH_PACKAGE])
        constructor_names = []

        constructor_names.concat(stripped.scan(
          /\b(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*require\(\s*["']#{Regexp.escape(RSPACK_REACT_REFRESH_PACKAGE)}["']\s*\)(?=\s*(?:[;,\)]|$))/
        ).flatten)
        constructor_names.concat(stripped.scan(
          /\bimport\s+([A-Za-z_$][\w$]*)\s*(?:,\s*\{[^}]*\}\s*)?\s+from\s*["']#{Regexp.escape(RSPACK_REACT_REFRESH_PACKAGE)}["']/
        ).flatten)
        constructor_names.concat(stripped.scan(
          /\bimport\s+\*\s+as\s+([A-Za-z_$][\w$]*)\s+from\s*["']#{Regexp.escape(RSPACK_REACT_REFRESH_PACKAGE)}["']/
        ).flatten)

        constructor_names.uniq.any? do |constructor_name|
          stripped.match?(/\bnew\s+#{Regexp.escape(constructor_name)}\s*\(/)
        end
      end

      # Returns the single active config path the runner would load, or nil. Mirrors the
      # resolution order in Shakapacker::Runner#find_rspack_config_with_fallback so the
      # doctor inspects the same file the build will actually use (and so unused sibling
      # configs in the same directory don't trigger spurious warnings).
      # NOTE: keep this candidate list in sync with Runner#find_rspack_config_with_fallback.
      def active_assets_bundler_config_path
        active_bundler_config_path_in(config.assets_bundler_config_path.to_s)
      end

      def active_bundler_config_path_in(config_dir)
        candidates = %w[ts js].map { |ext| Pathname.new(File.join(root_path.to_s, config_dir, "rspack.config.#{ext}")) }
        candidates += %w[ts js].map { |ext| Pathname.new(File.join(root_path.to_s, config_dir, "webpack.config.#{ext}")) }
        if default_rspack_config_dir?(config_dir)
          candidates += %w[ts js].map { |ext| Pathname.new(File.join(root_path.to_s, "config/webpack", "webpack.config.#{ext}")) }
        end

        candidates.find(&:exist?)
      end

      def read_active_assets_bundler_config(path)
        File.read(path)
      rescue SystemCallError => e
        add_info_warning("Unable to validate rspack cache configuration: #{e.message}")
        nil
      end

      def default_rspack_config_dir?(config_dir)
        # Intentionally exact-string match: mirrors the runner's own comparison,
        # so a trailing slash or Pathname argument won't spuriously add the config/webpack fallback.
        config_dir == "config/rspack"
      end

      def config_path_for_warning(path)
        expanded_root = root_path.expand_path
        expanded_path = path.expand_path

        return path.to_s unless expanded_path.to_s == expanded_root.to_s ||
                                expanded_path.to_s.start_with?("#{expanded_root}#{File::SEPARATOR}")

        path.relative_path_from(root_path)
      rescue ArgumentError
        path.to_s
      end

      def rspack_cache_disabled?(content)
        stripped = stripped_rspack_config_content(content)

        direct_export_cache_disabled?(stripped) || exported_variable_cache_disabled?(stripped)
      end

      def stripped_rspack_config_content(content)
        # Normalize quoted property keys before stripping string literals; otherwise
        # `'cache'` and `"cache"` collapse to `""` and the match below misses them.
        # Lookahead is restricted to horizontal whitespace so a multiline ternary
        # like `condition ? "cache"\n  : false` doesn't fold across the newline
        # and produce a spurious cache: false match.
        stripped = content.gsub(/(['"])(\w+)\1(?=[ \t]*:)/, '\2')

        stripped = strip_rspack_config_comments_and_literals(stripped)

        # Regex literal stripping runs after comment removal. The line-comment
        # pass above ignores escaped slashes so /https?:\/\/host/ stays intact
        # until this pass removes the whole regex literal. The heuristic can
        # false-match bare division like `a / b / c`, but rspack config files
        # rarely contain arithmetic near `cache:`, so the risk is low.
        stripped.gsub(%r{/(?:\\.|\[[^\]\n]*\]|[^/\n\\\[])+?/[gimsuy]*}, "")
      end

      def strip_rspack_config_comments_and_literals(content, preserve_literals: [])
        stripped = +""
        index = 0

        while index < content.length
          char = content[index]
          pair = content[index, 2]

          if pair == "/*"
            comment_end = content.index("*/", index + 2)
            if comment_end
              comment = content[index..comment_end + 1]
              stripped << comment.gsub(/[^\n]/, " ")
              index = comment_end + 2
            else
              stripped << content[index..].gsub(/[^\n]/, " ")
              break
            end
          elsif pair == "//"
            line_end = content.index("\n", index + 2) || content.length
            stripped << content[index...line_end].gsub(/[^\n]/, " ")
            index = line_end
          elsif char == "'" || char == '"'
            literal_end = index + 1
            escaped = false

            while literal_end < content.length
              current = content[literal_end]
              break if current == "\n"

              if escaped
                escaped = false
              elsif current == "\\"
                escaped = true
              elsif current == char
                literal_end += 1
                break
              end

              literal_end += 1
            end

            literal = content[index...literal_end]
            if preserved_js_string_literal?(literal, char, preserve_literals)
              stripped << literal
            else
              stripped << '""'
              stripped << literal.gsub(/[^\n]/, "")
            end
            index = literal_end
          elsif char == "`"
            literal_end = index + 1
            escaped = false
            closed = false

            while literal_end < content.length
              current = content[literal_end]

              if escaped
                escaped = false
              elsif current == "\\"
                escaped = true
              elsif current == "`"
                literal_end += 1
                closed = true
                break
              end

              literal_end += 1
            end

            if closed
              literal = content[index...literal_end]
              stripped << '""'
              stripped << literal.gsub(/[^\n]/, "")
              index = literal_end
            else
              stripped << char
              index += 1
            end
          else
            stripped << char
            index += 1
          end
        end

        stripped
      end

      def preserved_js_string_literal?(literal, quote, preserve_literals)
        return false unless literal.end_with?(quote)

        preserve_literals.include?(literal[1...-1])
      end

      def direct_export_cache_disabled?(stripped)
        # Match `cache: false` only near an exported config object at brace depth
        # 1. This avoids warning on local base config objects while still
        # catching the common direct export and generateRspackConfig patterns.
        #
        # Known false-positive gaps (rare; the "appears to be disabled" wording
        # is the user-visible mitigation):
        #   * Named intermediate export — `export const helper = { cache: false }`
        #     at depth 1 is flagged even when `helper` is not the final config and
        #     a separate `export default { … }` provides the real configuration.
        #   * ASI + prior `module.exports` — in semicolon-free code, an earlier
        #     `module.exports = merge(…)` followed by a local helper literal can
        #     leak into `statement_prefix` because `pre.rindex(";")` returns nil
        #     and the prefix spans back to the start of the file.
        stripped.to_enum(:scan, /\bcache\s*:\s*false\b/).any? do
          pre = Regexp.last_match.pre_match
          next false unless (pre.count("{") - pre.count("}")) == 1

          statement_prefix = pre[(pre.rindex(";") || -1) + 1..]
          # generateRspackConfig is Shakapacker's own helper; user-defined wrappers
          # like makeRspackConfig/createConfig are a known false-negative gap.
          statement_prefix.match?(/\bmodule\.exports\b|\bexport\s+default\b|\bexport\s+(?:const|let|var)\b|\bgenerateRspackConfig\b/)
        end
      end

      # Catches the `const cfg = { cache: false }; module.exports = cfg` pattern.
      # Composition via merge (`module.exports = merge(cfg, …)`) is a known
      # false-negative since the variable is never referenced by name in the
      # export statement. The `[^=;]+` type-annotation clause also stops at the
      # first `=`, so TypeScript generics with default type parameters such as
      # `Configuration<Opts = DefaultOpts>` are another known false-negative gap.
      def exported_variable_cache_disabled?(stripped)
        variable_declaration = /\b(?:const|let|var)\s+([A-Za-z_$][\w$]*)(?:\s*:\s*[^=;]+)?\s*=\s*\{/

        stripped.to_enum(:scan, variable_declaration).any? do
          name = Regexp.last_match[1]
          open_index = Regexp.last_match.end(0) - 1
          close_index = matching_closing_brace(stripped, open_index)
          next false unless close_index

          object_source = stripped[open_index..close_index]
          top_level_cache_false?(object_source) && exported_config_variable?(stripped, name)
        end
      end

      def top_level_cache_false?(object_source)
        object_source.to_enum(:scan, /\bcache\s*:\s*false\b/).any? do
          pre = Regexp.last_match.pre_match
          (pre.count("{") - pre.count("}")) == 1
        end
      end

      def exported_config_variable?(stripped, name)
        escaped_name = Regexp.escape(name)
        stripped.match?(/\bmodule\.exports\s*=\s*#{escaped_name}\b/) ||
          stripped.match?(/\bexport\s+default\s+#{escaped_name}\b/) ||
          stripped.match?(/\bexport\s*\{[^}]*\b#{escaped_name}\s+as\s+default\b/)
      end

      def matching_closing_brace(content, open_index)
        depth = 0

        content[open_index..].each_char.with_index do |char, offset|
          depth += 1 if char == "{"
          depth -= 1 if char == "}"

          return open_index + offset if depth.zero?
        end

        nil
      end

      def rspack_major_version
        majors = %w[@rspack/core @rspack/cli].filter_map do |package_name|
          rspack_major_version_for(package_name)
        end

        return 1 if majors.include?(1)

        majors.first
      end

      def rspack_major_version_for(package_name)
        installed = installed_rspack_major_version(package_name)
        return installed if installed

        rspack_declared_major_version_for(package_name)
      end

      def rspack_declared_major_version_for(package_name)
        rspack_major_from_specifier(package_json_dependency_version(package_name))
      end

      def rspack_major_from_specifier(version)
        return nil unless version

        # Only trust specifiers starting with a digit or ^/~ prefix followed by
        # a digit. Skip git+, file:, npm: aliases, "latest", "*", or ranges like
        # ">=1.5 <2". Accept shorthand forms (e.g. `^1`, `~1`, `1`, `1.x`) so
        # we still emit the v1 advisory when node_modules isn't populated yet.
        cleaned = version.strip
        if cleaned.include?("||")
          majors = cleaned.split("||").filter_map { |specifier| rspack_major_from_specifier(specifier) }
          return 1 if majors.include?(1)

          return majors.first
        end

        return nil unless cleaned.match?(/\A[\^~]?\d/)
        return nil if cleaned.match?(/(\s|[<>=:]|\A(?:git|file|link|workspace|npm):)/)
        return nil unless cleaned.match?(/\A[\^~]?\d+(?:\.(?:\d+|x|\*)){0,2}(?:-[0-9A-Za-z.-]+)?\z/i)

        match = cleaned.sub(/\A[\^~]/, "").match(/\A(\d+)/)
        match && match[1].to_i
      end

      def installed_rspack_major_version(package_name)
        rspack_pkg = installed_package_json_path(package_name)
        return nil unless rspack_pkg.exist?

        version = JSON.parse(File.read(rspack_pkg))["version"]
        match = version.to_s.match(/\A(\d+)\./)
        match && match[1].to_i
      rescue JSON::ParserError, SystemCallError
        nil
      end

      def package_json_dependency_version(name)
        return nil unless package_json_exists?

        declared_package_dependencies[name]
      end

      def package_version_status(package_name, minimum_version)
        minimum = Gem::Version.new(minimum_version)
        declared_specifier = package_json_dependency_version(package_name)
        declared = package_version_from_specifier(declared_specifier)
        installed = installed_package_version(package_name)

        {
          declared_below: declared && declared < minimum,
          installed_below: installed && installed < minimum
        }
      end

      def package_version_from_specifier(version)
        return nil unless version

        cleaned = version.strip
        if cleaned.include?("||")
          versions = cleaned.split("||").filter_map { |specifier| package_version_from_specifier(specifier) }
          return versions.min
        end

        return package_version_from_range_specifier(cleaned) if cleaned.match?(/[<>=]/)
        return nil unless cleaned.match?(/\A[\^~]?\d/)
        return nil if cleaned.match?(/(\s|\|\||:|\A(?:git|file|link|workspace|npm):)/)

        match = cleaned.sub(/\A[\^~]/, "").match(/\A(\d+(?:\.\d+){0,2})(?:-[0-9A-Za-z.-]+)?\z/)
        match && Gem::Version.new(match[1])
      rescue ArgumentError
        nil
      end

      def package_version_from_range_specifier(specifier)
        lower_bounds = specifier.scan(/(?:\A|\s)(?:>=|>)\s*(\d+(?:\.\d+){0,2})(?:-[0-9A-Za-z.-]+)?/)
        versions = lower_bounds.flatten.map { |version| Gem::Version.new(version) }

        versions.max
      rescue ArgumentError
        nil
      end

      def package_specifier_allows_version_or_newer?(specifier, minimum)
        return false unless specifier

        cleaned = specifier.strip
        if cleaned.include?("||")
          return cleaned.split("||").any? { |part| package_specifier_allows_version_or_newer?(part, minimum) }
        end
        return false if cleaned.match?(/(:|\A(?:git|file|link|workspace|npm):)/)

        if cleaned.match?(/[<>=]/)
          return package_range_specifier_allows_version_or_newer?(cleaned, minimum)
        end

        version = package_version_from_specifier(cleaned)
        version && version >= minimum
      end

      def package_range_specifier_allows_version_or_newer?(specifier, minimum)
        comparators = specifier.scan(/(?:\A|\s)(<=|<|>=|>|=)\s*(\d+(?:\.\d+){0,2})(?:-[0-9A-Za-z.-]+)?/)
        return false if comparators.empty?

        equalities = comparators.select { |operator, _version| operator == "=" }
        return equalities.any? { |_operator, version| Gem::Version.new(version) >= minimum } if equalities.any?

        upper_bounds = comparators.select { |operator, _version| VERSION_UPPER_BOUND_OPERATORS.include?(operator) }
        upper_bounds.all? do |operator, version|
          parsed = Gem::Version.new(version)
          operator == "<" ? parsed > minimum : parsed >= minimum
        end
      rescue ArgumentError
        false
      end

      def declared_package_dependencies
        @declared_package_dependencies ||= begin
          package_json_paths.reverse_each.each_with_object({}) do |path, dependencies|
            package_json = parse_package_json(path)
            next unless package_json

            dependencies.merge!(installable_package_dependencies(package_json))
          end
        end
      end

      def installable_package_dependencies(package_json)
        # Later sections take precedence when the same package is declared in more than one section.
        (package_json["optionalDependencies"] || {})
          .merge(package_json["devDependencies"] || {})
          .merge(package_json["dependencies"] || {})
      end

      def installed_package_version(package_name)
        package_json = installed_package_json_path(package_name)
        return nil unless package_json.exist?

        version = JSON.parse(File.read(package_json))["version"]
        match = version.to_s.match(/\A(\d+(?:\.\d+){0,2})/)
        match && Gem::Version.new(match[1])
      rescue JSON::ParserError, SystemCallError, ArgumentError
        nil
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
        transpiler = javascript_transpiler
        if transpiler == "babel"
          check_optional_dependency("@babel/preset-typescript", @warnings, "TypeScript with Babel")
        elsif transpiler != "esbuild" && transpiler != "swc"
          check_optional_dependency("ts-loader", @warnings, "TypeScript")
        end
      end

      def check_sass_dependencies
        check_dependency("sass-loader", @issues, "Sass/SCSS")
        unless SASS_IMPLEMENTATION_PACKAGES.any? { |package_name| package_installed?(package_name) }
          @issues << SASS_IMPLEMENTATION_DEPENDENCY_MESSAGE
        end
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
          add_warning("Optional dependency '#{package_name}' for #{description} is not installed")
        end
      end

      def package_installed?(package_name)
        return false unless package_json_exists?

        declared_package_dependencies.key?(package_name)
      end

      def package_json_exists?
        package_json_paths.any?
      end

      def javascript_transpiler_configured?
        !javascript_transpiler_env_override.nil? ||
          config_key_configured?(:javascript_transpiler) ||
          config_key_present?(:webpack_loader)
      end

      def javascript_transpiler
        return @resolved_javascript_transpiler if defined?(@resolved_javascript_transpiler)

        @resolved_javascript_transpiler =
          if javascript_transpiler_configured?
            transpiler = javascript_transpiler_env_override || config.javascript_transpiler
            blank_config_value?(transpiler) ? default_javascript_transpiler : transpiler
          else
            implicit_javascript_transpiler
          end
      end

      def explicit_javascript_transpiler
        return javascript_transpiler_env_override if javascript_transpiler_env_override
        return nil unless javascript_transpiler_configured?

        javascript_transpiler
      end

      def javascript_transpiler_env_override
        value = ENV["SHAKAPACKER_JAVASCRIPT_TRANSPILER"]
        return nil if value.nil? || value.empty?

        value
      end

      def assets_bundler_configured?
        assets_bundler_override_configured? ||
          ENV.key?("SHAKAPACKER_ASSETS_BUNDLER") ||
          !assets_bundler_env_override.nil? ||
          config_key_present?(:assets_bundler) ||
          config_key_present?(:bundler)
      end

      def assets_bundler
        config.assets_bundler
      end

      def assets_bundler_env_override
        value = ENV["SHAKAPACKER_ASSETS_BUNDLER"]
        return nil if value.nil? || value.empty?

        value
      end

      def assets_bundler_override_configured?
        config.respond_to?(:bundler_override) && !blank_config_value?(config.bundler_override)
      end

      def empty_assets_bundler_env_override?
        ENV.key?("SHAKAPACKER_ASSETS_BUNDLER") && ENV["SHAKAPACKER_ASSETS_BUNDLER"].empty?
      end

      def report_empty_assets_bundler_env_override
        return if @empty_assets_bundler_env_override_reported

        @issues << "SHAKAPACKER_ASSETS_BUNDLER is set but empty. Unset it, or set it to 'webpack' or 'rspack'."
        @empty_assets_bundler_env_override_reported = true
      end

      def blank_config_value?(value)
        value.nil? || (value.is_a?(String) && value.strip.empty?) || (value.respond_to?(:empty?) && value.empty?)
      end

      def default_javascript_transpiler
        assets_bundler == "rspack" ? "swc" : "babel"
      end

      def config_key_present?(key)
        value = config_value(key)
        value.is_a?(String) && !value.strip.empty?
      end

      def config_key_configured?(key)
        return false unless config.respond_to?(:data)

        data = config.data
        data.respond_to?(:key?) && data.key?(key) && !blank_config_value?(data[key])
      end

      def config_value(key)
        return nil unless config.respond_to?(:data)

        data = config.data
        return nil unless data.respond_to?(:key?) && data.key?(key)

        data[key]
      end

      def parse_package_json(path)
        JSON.parse(File.read(path))
      rescue JSON::ParserError, SystemCallError
        nil
      end

      def package_json_key?(key)
        package_json_paths.any? do |path|
          package_json = parse_package_json(path)
          package_json.is_a?(Hash) && package_json.key?(key)
        end
      end

      def package_json_paths
        @package_json_paths ||= package_root_paths
          .map { |path| path.join("package.json") }
          .select(&:exist?)
      end

      def javascript_package_root_path
        @javascript_package_root_path ||= begin
          source_path = config.source_path.expand_path
          app_root = root_path.expand_path

          if path_within?(source_path, app_root)
            current = source_path
            loop do
              break current if current.join("package.json").exist?
              break root_path if current == app_root

              parent = current.dirname
              break root_path if parent == current

              current = parent
            end
          else
            root_path
          end
        rescue StandardError
          root_path
        end
      end

      def node_modules_path
        node_modules_paths.first
      end

      def node_modules_paths
        @node_modules_paths ||= package_root_paths.map { |path| path.join("node_modules") }
      end

      def installed_package_json_path(package_name)
        node_modules_paths
          .map { |path| path.join(package_name, "package.json") }
          .find(&:exist?) || node_modules_path.join(package_name, "package.json")
      end

      def package_root_paths
        @package_root_paths ||= [javascript_package_root_path, root_path].uniq
      end

      def package_root_marker?(path)
        # Keep aligned with shakapacker_package_root_marker? in the helper binstubs.
        PACKAGE_ROOT_MARKERS.any? { |entry| path.join(entry).exist? }
      end

      def path_within?(path, parent)
        path.to_s == parent.to_s || path.to_s.start_with?("#{parent}#{File::SEPARATOR}")
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
        root_package_manager = package_manager_for(root_path)

        package_manager_root_paths.each do |package_root|
          next if package_root == root_path

          package_manager_name = package_manager_for(package_root)
          next unless package_manager_name

          return package_manager_name if package_root.join("package.json").exist? || root_package_manager.nil?
        end

        root_package_manager
      end

      def package_manager_for(package_root)
        PACKAGE_MANAGER_LOCKFILES.each do |lockfile, package_manager_name|
          return package_manager_name if File.exist?(package_root.join(lockfile))
        end

        nil
      end

      def package_manager_root_paths
        @package_manager_root_paths ||= [javascript_package_manager_root_path, root_path].uniq
      end

      def javascript_package_manager_root_path
        @javascript_package_manager_root_path ||= begin
          source_path = config.source_path.expand_path
          app_root = root_path.expand_path

          if path_within?(source_path, app_root)
            current = source_path
            loop do
              break current if package_root_marker?(current)
              break root_path if current == app_root

              parent = current.dirname
              break root_path if parent == current

              current = parent
            end
          else
            root_path
          end
        rescue StandardError
          root_path
        end
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

          def verbose?
            doctor.options[:verbose]
          end

          def print_header
            puts "Running Shakapacker doctor..."
            puts "=" * 60
            puts ""
            if verbose?
              puts "Mode: Verbose (showing all checks)"
              puts ""
            end
          end

          def print_checks
            if doctor.config.config_path.exist?
              config_relative_path = doctor.config.config_path.relative_path_from(doctor.root_path)
              puts "✓ Configuration file found (#{config_relative_path})"
              if verbose?
                puts "  Assets bundler: #{doctor.send(:assets_bundler)}"
                puts "  Source path: #{doctor.config.source_path.relative_path_from(doctor.root_path)}"
                puts "  Public output path: #{doctor.config.public_output_path.relative_path_from(doctor.root_path)}"
              end
              print_transpiler_status
              print_bundler_status
              print_css_status
            elsif verbose?
              puts "✗ Configuration file not found"
            end

            print_node_status
            print_package_manager_status
            print_binstub_status
            print_verbose_checks if verbose?
            print_info_messages
          end

          def print_verbose_checks
            puts "\nVerbose diagnostics:"
            print_environment_info
            print_version_info
            print_path_info
            print_config_values
          end

          def print_environment_info
            rails_env = defined?(Rails) ? Rails.env : ENV["RAILS_ENV"]
            node_env = ENV["NODE_ENV"]
            puts "  • Rails environment: #{rails_env || 'not set'}"
            puts "  • Node environment: #{node_env || 'not set'}"
          end

          def print_version_info
            return unless doctor.send(:package_json_exists?)

            npm_version = doctor.send(:package_json_dependency_version, "shakapacker")
            puts "  • Shakapacker gem version: #{Shakapacker::VERSION}"
            puts "  • Shakapacker npm version: #{npm_version || 'not installed'}"
          end

          def print_path_info
            puts "  • Root path: #{doctor.root_path}"
            return unless doctor.config.config_path.exist?

            puts "  • Cache path: #{doctor.config.cache_path}"
            puts "  • Manifest path: #{doctor.config.manifest_path}"
          end

          def print_config_values
            return unless doctor.config.config_path.exist?

            puts "\nConfiguration values for '#{doctor.config.env}' environment:"
            config_data = doctor.config.data

            if config_data.any?
              print_config_data(config_data)
            else
              puts "  (using bundled defaults - no environment-specific config found)"
            end
          end

          def print_config_data(config_data)
            config_data.each do |key, value|
              formatted_value = format_config_value(value)
              puts "  • #{key}: #{formatted_value}"
            end
          end

          def format_config_value(value)
            case value
            when Array
              format_array_value(value)
            when Hash
              format_hash_value(value)
            else
              value.inspect
            end
          end

          def format_array_value(array)
            if array.length > 3
              "#{array.first(3).inspect}... (#{array.length} items)"
            else
              array.inspect
            end
          end

          def format_hash_value(hash)
            if hash.length > 3
              "{...} (#{hash.length} keys)"
            else
              hash.inspect
            end
          end

          def print_transpiler_status
            transpiler = doctor.send(:javascript_transpiler)
            return if transpiler.nil? || transpiler == "none"

            loader_name = "#{transpiler}-loader"
            if doctor.send(:package_installed?, loader_name)
              puts "✓ JavaScript transpiler: #{loader_name} is installed"
            end
          end

          def print_bundler_status
            bundler = doctor.send(:assets_bundler)
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
            required_paths = REQUIRED_BINSTUBS.keys

            existing_required = required_paths.select { |b| doctor.root_path.join(b).exist? }
            existing_optional = OPTIONAL_BINSTUBS.select { |b| doctor.root_path.join(b).exist? }

            if existing_required.length == required_paths.length
              puts "✓ All required Shakapacker binstubs found (#{existing_required.join(', ')})"
            elsif existing_required.any?
              existing_required.each do |binstub|
                puts "✓ #{binstub} found"
              end
            end

            existing_optional.each do |binstub|
              puts "✓ #{binstub} found (optional)"
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
            puts ""

            if doctor.issues.empty? && doctor.warnings.empty?
              puts "✅ No issues found! Shakapacker appears to be configured correctly."
            else
              print_issues if doctor.issues.any?
              print_warnings if doctor.warnings.any?
              print_fix_instructions if has_dependency_issues?
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
            main_item_count = doctor.warnings.count { |w| !subitem?(w) }
            puts "⚠️  Warnings (#{main_item_count}):"
            puts ""

            item_number = 0
            doctor.warnings.each do |warning|
              if subitem?(warning)
                print_subitem(warning)
              else
                item_number += 1
                print_main_item(item_number, warning)
              end
            end
            puts ""
          end

          def subitem?(warning)
            warning[:fix] || warning[:message].start_with?("  ")
          end

          def print_subitem(warning)
            # Fix instructions align at column 16 (length of "N. [RECOMMENDED]  ")
            # This keeps every Fix line aligned regardless of category.
            subitem_prefix = " " * 15
            text = warning[:fix] ? "Fix: #{warning[:message]}" : warning[:message]
            wrapped = wrap_text(text, 100, subitem_prefix)
            puts wrapped
          end

          def print_main_item(item_number, warning)
            category_prefix = case warning[:category]
                              when :action_required then "[REQUIRED]"
                              when :info then "[INFO]"
                              when :recommended then "[RECOMMENDED]"
                              else
                                ""
            end

            # Format: N. [CATEGORY]  Message
            prefix = "#{item_number}. #{category_prefix}  "
            wrapped = wrap_text(warning[:message], 100, prefix)
            puts wrapped
          end

          def wrap_text(text, max_width, prefix)
            text = text.strip
            available_width = max_width - prefix.length

            return prefix + text if text.length <= available_width

            lines = build_wrapped_lines(text, available_width)
            format_wrapped_output(lines, prefix)
          end

          def build_wrapped_lines(text, available_width)
            words = text.split(" ")
            lines = []
            current_line = []
            current_length = 0

            words.each do |word|
              word_length = word.length + (current_line.empty? ? 0 : 1)

              if current_length + word_length <= available_width
                current_line << word
                current_length += word_length
              else
                lines << current_line.join(" ") unless current_line.empty?
                current_line = [word]
                current_length = word.length
              end
            end

            lines << current_line.join(" ") unless current_line.empty?
            lines
          end

          def format_wrapped_output(lines, prefix)
            result = prefix + lines[0]
            indent = " " * prefix.length

            lines[1..].each do |line|
              result += "\n#{indent}#{line}"
            end

            result
          end

          def has_dependency_issues?
            all_messages = doctor.issues + doctor.warnings.map { |w| w[:message] }
            all_messages.any? { |msg| dependency_issue?(msg) }
          end

          def dependency_issue?(message)
            return false if message.include?("Optional")

            missing_dependency?(message) || not_installed?(message)
          end

          def missing_dependency?(message)
            message.include?("Missing") && message.include?("dependency")
          end

          def not_installed?(message)
            message.include?("not installed") || message.include?("is not installed")
          end

          def print_fix_instructions
            package_manager = doctor.send(:package_manager)
            puts "To fix missing dependencies, run:"
            puts "  #{package_manager_install_command(package_manager)}"
            puts ""
            puts "For debugging configuration issues, export your webpack/rspack config:"
            puts "  bin/shakapacker-config --doctor"
            puts "  (Exports annotated YAML configs for dev and production - best for troubleshooting)"
            puts ""
            puts "  See 'bin/shakapacker-config --help' for more options"
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

require "json"
require "pathname"

module Shakapacker
  class Doctor
    attr_reader :config, :root_path, :issues, :warnings

    def initialize(config = nil, root_path = nil)
      @config = config || Shakapacker.config
      @root_path = root_path || (defined?(Rails) ? Rails.root : Pathname.new(Dir.pwd))
      @issues = []
      @warnings = []
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
        check_config_file
        check_node_installation
        check_package_manager
        check_binstub
        check_javascript_transpiler_dependencies if config_exists?
        check_css_dependencies
        check_bundler_dependencies if config_exists?
        check_file_type_dependencies if config_exists?
      end

      def check_config_file
        unless config.config_path.exist?
          @issues << "Configuration file not found at #{config.config_path}"
        end
      end

      def check_node_installation
        node_version = `node --version`.strip
      rescue Errno::ENOENT
        @issues << "Node.js is not installed or not in PATH"
      end

      def check_package_manager
        unless package_manager
          @issues << "No package manager lock file found (package-lock.json, yarn.lock, or pnpm-lock.yaml)"
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
        return if transpiler.nil? || transpiler == "none"

        loader_name = "#{transpiler}-loader"
        unless package_installed?(loader_name)
          @issues << "Missing required dependency '#{loader_name}' for JavaScript transpiler '#{transpiler}'"
        end
      end

      def check_css_dependencies
        check_dependency("css-loader", @issues, "CSS")
        check_dependency("style-loader", @issues, "CSS (style-loader)")
        check_optional_dependency("mini-css-extract-plugin", @warnings, "CSS extraction")
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
        package_json_path = root_path.join("package.json")
        return false unless package_json_path.exist?

        package_json = JSON.parse(File.read(package_json_path))
        dependencies = (package_json["dependencies"] || {}).merge(package_json["devDependencies"] || {})
        dependencies.key?(package_name)
      rescue JSON::ParserError
        false
      end

      def config_exists?
        config.config_path.exist?
      end

      def typescript_files_exist?
        Dir.glob(File.join(config.source_path, "**/*.{ts,tsx}")).any?
      end

      def sass_files_exist?
        Dir.glob(File.join(config.source_path, "**/*.{sass,scss}")).any?
      end

      def less_files_exist?
        Dir.glob(File.join(config.source_path, "**/*.less")).any?
      end

      def stylus_files_exist?
        Dir.glob(File.join(config.source_path, "**/*.{styl,stylus}")).any?
      end

      def postcss_config_exists?
        root_path.join("postcss.config.js").exist?
      end

      def package_manager
        @package_manager ||= detect_package_manager
      end

      def detect_package_manager
        return "pnpm" if File.exist?(root_path.join("pnpm-lock.yaml"))
        return "yarn" if File.exist?(root_path.join("yarn.lock"))
        return "npm" if File.exist?(root_path.join("package-lock.json"))
        nil
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
              node_version = `node --version`.strip
              puts "✓ Node.js #{node_version} found"
            rescue Errno::ENOENT
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
            when "pnpm" then "pnpm add -D [package-name]"
            when "yarn" then "yarn add -D [package-name]"
            when "npm" then "npm install --save-dev [package-name]"
            else "npm install --save-dev [package-name]"
            end
          end
      end
  end
end

# frozen_string_literal: true

module Shakapacker
  # Centralized configuration helper for detecting transpiler settings
  class ConfigurationHelper
    class << self
      # Detects which JavaScript transpiler to use based on various factors
      # Priority order:
      # 1. Environment variable USE_BABEL_PACKAGES (backward compatibility)
      # 2. Environment variable JAVASCRIPT_TRANSPILER
      # 3. Existing babel configuration files
      # 4. Existing configuration in shakapacker.yml
      # 5. Default to 'swc'
      def detect_transpiler(rails_root: Rails.root)
        # Check environment variables first
        if ENV["USE_BABEL_PACKAGES"]
          return "babel"
        elsif ENV["JAVASCRIPT_TRANSPILER"]
          return ENV["JAVASCRIPT_TRANSPILER"]
        end

        # Check for existing babel configuration
        if babel_configured?(rails_root)
          return "babel"
        end

        # Check existing shakapacker.yml config
        existing_config = read_existing_config(rails_root)
        if existing_config["javascript_transpiler"]
          return existing_config["javascript_transpiler"]
        end

        # Default to SWC
        "swc"
      end

      # Reads and caches the shakapacker configuration
      def read_existing_config(rails_root)
        config_path = rails_root.join("config/shakapacker.yml")
        return {} unless File.exist?(config_path)

        begin
          YAML.load_file(config_path) || {}
        rescue Psych::SyntaxError => e
          warn "Warning: shakapacker.yml has invalid syntax: #{e.message}"
          {}
        end
      end

      # Checks if babel is already configured in the project
      def babel_configured?(rails_root)
        babel_config_exists?(rails_root) || babel_in_package_json?(rails_root)
      end

      private

      def babel_config_exists?(rails_root)
        %w[.babelrc babel.config.js babel.config.json .babelrc.js].any? do |file|
          File.exist?(rails_root.join(file))
        end
      end

      def babel_in_package_json?(rails_root)
        package_json_path = rails_root.join("package.json")
        return false unless File.exist?(package_json_path)

        begin
          content = JSON.parse(File.read(package_json_path))
          content.key?("babel") ||
            has_babel_dependency?(content, "dependencies") ||
            has_babel_dependency?(content, "devDependencies")
        rescue JSON::ParserError
          false
        end
      end

      def has_babel_dependency?(package_json, dep_type)
        deps = package_json[dep_type] || {}
        deps.key?("@babel/core") || deps.key?("babel-loader")
      end
    end
  end
end
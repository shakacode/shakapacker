require "yaml"
require "pathname"

module Shakapacker
  class BuildConfigLoader
    attr_reader :config_file_path

    def initialize(config_file_path = nil)
      @config_file_path = config_file_path || File.join(Dir.pwd, ".bundler-config.yml")
    end

    def exists?
      File.exist?(@config_file_path)
    end

    def load_build(build_name)
      unless exists?
        raise ArgumentError, "Config file not found: #{@config_file_path}\n" \
                            "Run 'bin/export-bundler-config --init' to generate a sample config file."
      end

      config = YAML.load_file(@config_file_path)

      unless config["builds"]&.is_a?(Hash)
        raise ArgumentError, "Config file must contain a 'builds' object"
      end

      build = config["builds"][build_name]
      unless build
        available = config["builds"].keys.join(", ")
        raise ArgumentError, "Build '#{build_name}' not found in config file.\n" \
                            "Available builds: #{available}\n" \
                            "Use 'bin/export-bundler-config --list-builds' to see all available builds."
      end

      build
    end

    def resolve_build_config(build_name, default_bundler: "webpack")
      build = load_build(build_name)
      config = YAML.load_file(@config_file_path)

      # Resolve bundler with precedence: build.bundler > config.default_bundler > default_bundler
      bundler = build["bundler"] || config["default_bundler"] || default_bundler

      # Get environment variables
      environment = build["environment"] || {}

      # Get config file path if specified
      config_file = build["config"]
      if config_file
        # Expand ${BUNDLER} variable
        config_file = config_file.gsub("${BUNDLER}", bundler)
      end

      # Get bundler_env for --env flags
      bundler_env = build["bundler_env"] || {}

      # Get outputs
      outputs = build["outputs"] || []

      {
        name: build_name,
        description: build["description"],
        bundler: bundler,
        environment: environment,
        bundler_env: bundler_env,
        outputs: outputs,
        config_file: config_file
      }
    end

    def uses_dev_server?(build_config)
      env = build_config[:environment]
      env["WEBPACK_SERVE"] == "true" || env["HMR"] == "true"
    end
  end
end

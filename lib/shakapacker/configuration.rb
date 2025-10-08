require "yaml"
require "json"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/hash/indifferent_access"

class Shakapacker::Configuration
  class << self
    attr_accessor :installing
  end

  attr_reader :root_path, :config_path, :env

  def initialize(root_path:, config_path:, env:)
    @root_path = root_path
    @env = env
    @config_path = config_path
  end

  def dev_server
    fetch(:dev_server)
  end

  def compile?
    fetch(:compile)
  end

  def nested_entries?
    fetch(:nested_entries)
  end

  def ensure_consistent_versioning?
    fetch(:ensure_consistent_versioning)
  end

  def shakapacker_precompile?
    # ENV of false takes precedence
    return false if %w(no false n f).include?(ENV["SHAKAPACKER_PRECOMPILE"])
    return true if %w(yes true y t).include?(ENV["SHAKAPACKER_PRECOMPILE"])

    return false unless config_path.exist?
    fetch(:shakapacker_precompile)
  end

  def source_path
    root_path.join(fetch(:source_path))
  end

  def additional_paths
    fetch(:additional_paths)
  end

  def source_entry_path
    source_path.join(relative_path(fetch(:source_entry_path)))
  end

  def manifest_path
    if data.has_key?(:manifest_path)
      root_path.join(fetch(:manifest_path))
    else
      public_output_path.join("manifest.json")
    end
  end

  def public_manifest_path
    manifest_path
  end

  def public_path
    root_path.join(fetch(:public_root_path))
  end

  def private_output_path
    private_path = fetch(:private_output_path)
    return nil unless private_path
    validate_output_paths!
    root_path.join(private_path)
  end

  def public_output_path
    public_path.join(fetch(:public_output_path))
  end

  def cache_manifest?
    fetch(:cache_manifest)
  end

  def cache_path
    root_path.join(fetch(:cache_path))
  end

  def webpack_compile_output?
    fetch(:webpack_compile_output)
  end

  def compiler_strategy
    fetch(:compiler_strategy)
  end

  def assets_bundler
    # Show deprecation warning if using old 'bundler' key
    if data.has_key?(:bundler) && !data.has_key?(:assets_bundler)
      $stderr.puts "⚠️  DEPRECATION WARNING: The 'bundler' configuration option is deprecated. Please use 'assets_bundler' instead to avoid confusion with Ruby's Bundler gem manager."
    end
    ENV["SHAKAPACKER_ASSETS_BUNDLER"] || fetch(:assets_bundler) || fetch(:bundler) || "webpack"
  end

  # Deprecated: Use assets_bundler instead
  def bundler
    assets_bundler
  end

  def rspack?
    assets_bundler == "rspack"
  end

  def webpack?
    assets_bundler == "webpack"
  end

  def javascript_transpiler
    # Show deprecation warning if using old 'webpack_loader' key
    if data.has_key?(:webpack_loader) && !data.has_key?(:javascript_transpiler)
      $stderr.puts "⚠️  DEPRECATION WARNING: The 'webpack_loader' configuration option is deprecated. Please use 'javascript_transpiler' instead as it better reflects its purpose of configuring JavaScript transpilation regardless of the bundler used."
    end

    # Use explicit config if set, otherwise default based on bundler
    transpiler = fetch(:javascript_transpiler) || fetch(:webpack_loader) || default_javascript_transpiler

    # Validate transpiler configuration
    validate_transpiler_configuration(transpiler) unless self.class.installing

    transpiler
  end

  # Deprecated: Use javascript_transpiler instead
  def webpack_loader
    javascript_transpiler
  end

  private

    def default_javascript_transpiler
      # RSpack has built-in SWC support, use it by default
      rspack? ? "swc" : "babel"
    end

    def validate_transpiler_configuration(transpiler)
      return unless ENV["NODE_ENV"] != "test" # Skip validation in test environment

      # Check if package.json exists
      package_json_path = root_path.join("package.json")
      return unless package_json_path.exist?

      begin
        package_json = JSON.parse(File.read(package_json_path))
        all_deps = (package_json["dependencies"] || {}).merge(package_json["devDependencies"] || {})

        # Check for transpiler mismatch
        has_babel = all_deps.keys.any? { |pkg| pkg.start_with?("@babel/", "babel-") }
        has_swc = all_deps.keys.any? { |pkg| pkg.include?("swc") }
        has_esbuild = all_deps.keys.any? { |pkg| pkg.include?("esbuild") }

        case transpiler
        when "babel"
          if !has_babel && has_swc
            warn_transpiler_mismatch("Babel", "SWC packages found but Babel is configured")
          end
        when "swc"
          if !has_swc && has_babel
            warn_transpiler_mismatch("SWC", "Babel packages found but SWC is configured")
          end
        when "esbuild"
          if !has_esbuild && (has_babel || has_swc)
            other = has_babel ? "Babel" : "SWC"
            warn_transpiler_mismatch("esbuild", "#{other} packages found but esbuild is configured")
          end
        end
      rescue JSON::ParserError
        # Ignore if package.json is malformed
      end
    end

    def warn_transpiler_mismatch(configured, message)
      $stderr.puts <<~WARNING
        ⚠️  Transpiler Configuration Mismatch Detected:
           #{message}
           Configured transpiler: #{configured}
        #{'   '}
           This might cause unexpected behavior or build failures.
        #{'   '}
           To fix this:
           1. Run 'rails shakapacker:migrate_to_swc' to migrate to SWC (recommended for 20x faster builds)
           2. Or install the correct packages for #{configured}
           3. Or update your shakapacker.yml to match your installed packages
      WARNING
    end

  public

  def fetch(key)
    data.fetch(key, defaults[key])
  end

  def asset_host
    ENV.fetch(
      "SHAKAPACKER_ASSET_HOST",
      fetch(:asset_host) || ActionController::Base.helpers.compute_asset_host
    )
  end

  def integrity
    fetch(:integrity)
  end

  private
    def validate_output_paths!
      # Skip validation if already validated to avoid redundant checks
      return if @validated_output_paths
      @validated_output_paths = true

      # Only validate when both paths are configured
      return unless fetch(:private_output_path) && fetch(:public_output_path)

      private_path_str, public_path_str = resolve_paths_for_comparison

      if private_path_str == public_path_str
        raise "Shakapacker configuration error: private_output_path and public_output_path must be different. " \
              "Both paths resolve to '#{private_path_str}'. " \
              "The private_output_path is for server-side bundles (e.g., SSR) that should not be served publicly."
      end
    end

    def resolve_paths_for_comparison
      private_full_path = root_path.join(fetch(:private_output_path))
      public_full_path = root_path.join(fetch(:public_root_path), fetch(:public_output_path))

      # Create directories if they don't exist (for testing)
      private_full_path.mkpath unless private_full_path.exist?
      public_full_path.mkpath unless public_full_path.exist?

      # Use realpath to resolve symbolic links and relative paths
      [private_full_path.realpath.to_s, public_full_path.realpath.to_s]
    rescue Errno::ENOENT
      # If paths don't exist yet, fall back to cleanpath for comparison
      [private_full_path.cleanpath.to_s, public_full_path.cleanpath.to_s]
    end

    def data
      @data ||= load
    end

    def load
      config = begin
        YAML.load_file(config_path.to_s, aliases: true)
      rescue ArgumentError
        YAML.load_file(config_path.to_s)
      end
      env_config = config[env] || config[Shakapacker::DEFAULT_ENV] || config["default"]
      symbolized_config = env_config&.deep_symbolize_keys || {}

      return symbolized_config
    rescue Errno::ENOENT => e
      if self.class.installing
        {}
      else
        raise "Shakapacker configuration file not found #{config_path}. " \
              "Please run rails shakapacker:install " \
              "Error: #{e.message}"
      end
    rescue Psych::SyntaxError => e
      raise "YAML syntax error occurred while parsing #{config_path}. " \
            "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
            "Error: #{e.message}"
    end

    def defaults
      @defaults ||= begin
        path = File.expand_path("../../install/config/shakapacker.yml", __FILE__)
        config = begin
          YAML.load_file(path, aliases: true)
        rescue ArgumentError
          YAML.load_file(path)
        end
        HashWithIndifferentAccess.new(config[env] || config[Shakapacker::DEFAULT_ENV])
      end
    end

    def relative_path(path)
      return ".#{path}" if path.start_with?("/")

      path
    end
end

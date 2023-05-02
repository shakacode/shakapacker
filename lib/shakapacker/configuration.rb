require "yaml"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/hash/deep_merge"
require "shakapacker/utils"

class Shakapacker::Configuration
  # For backward compatibility.
  # Use ENV["SHAKAPACKER_INSTALLING"] directly.
  class << self
    def installing
      Shakapacker.puts_deprecation_message(
        Shakapacker.short_deprecation_message(
          "Shakapacker::Configuration.installing",
          'ENV["SHAKAPACKER_INSTALLING"]'
        )
      )

      ENV["SHAKAPACKER_INSTALLING"] == "true"
    end

    def installing=(is_installing)
      Shakapacker.puts_deprecation_message(
        Shakapacker.short_deprecation_message(
          "Shakapacker::Configuration.installing",
          'ENV["SHAKAPACKER_INSTALLING"]'
        )
      )

      boolean_value = false
      boolean_value = true if is_installing == true || is_installing =~ /^(true|t|yes|y|1)$/i
      ENV["SHAKAPACKER_INSTALLING"] = boolean_value.to_s
    end
  end

  attr_reader :root_path, :env

  def initialize(root_path:, custom_config: nil, default_config: nil, env:)
    @root_path = root_path

    # For backward compatibility
    Shakapacker.set_shakapacker_env_variables_for_backward_compatibility

    @custom_config = if custom_config
      custom_config
    else
      config_path = ENV["SHAKAPACKER_CONFIG"] ? Pathname.new(ENV["SHAKAPACKER_CONFIG"]) : Rails.root.join("config/shakapacker.yml")
      Shakapacker::Utils.parse_config_file_to_hash(config_path)
    end

    @custom_config = HashWithIndifferentAccess.new(@custom_config)

    @default_config = default_config || Shakapacker::Utils.parse_config_file_to_hash(File.expand_path("../../install/config/shakapacker.yml", __FILE__))
    @default_config = HashWithIndifferentAccess.new(@default_config)
    @env = env
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

    fetch(:shakapacker_precompile)
  end

  def webpacker_precompile?
    Shakapacker.puts_deprecation_message(
      Shakapacker.short_deprecation_message(
        "webpacker_precompile?",
        "shakapacker_precompile?"
      )
    )

    shakapacker_precompile?
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

  def public_output_path
    public_path.join(fetch(:public_output_path))
  end

  def cache_manifest?
    fetch(:cache_manifest)
  end

  def cache_path
    root_path.join(fetch(:cache_path))
  end

  def check_yarn_integrity=(value)
    warn <<~EOS
      Shakapacker::Configuration#check_yarn_integrity=(value) is obsolete. The integrity
      check has been removed from Webpacker (https://github.com/rails/webpacker/pull/2518)
      so changing this setting will have no effect.
    EOS
  end

  def webpack_compile_output?
    fetch(:webpack_compile_output)
  end

  def compiler_strategy
    fetch(:compiler_strategy)
  end

  def fetch(key)
    return data.fetch(key, nil) unless key == :webpacker_precompile

    # for backward compatibility
    Shakapacker.puts_deprecation_message(
      Shakapacker.short_deprecation_message(
        "webpacker_precompile",
        "shakapacker_precompile"
      )
    )

    data.fetch(key)
  end

  private
    def data
      @data ||= config_for_env
    end

    def config_for_env
      custom_config_for_env = @custom_config[env] || {}
      default_config_for_env = @default_config[env] || @default_config[Shakapacker::DEFAULT_ENV] || {}

      default_config_for_env.deep_merge(custom_config_for_env)
    end

    def relative_path(path)
      return ".#{path}" if path.start_with?("/")

      path
    end
end

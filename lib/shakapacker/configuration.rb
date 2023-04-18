require "yaml"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/hash/deep_merge"
require "shakapacker/helper"

class Shakapacker::Configuration
  class << self
    attr_accessor :installing
  end

  attr_reader :root_path, :env

  def initialize(root_path:, custom_config: nil, default_config: nil, env:)
    @root_path = root_path

    # For backward compatibility
    Shakapacker.set_shakapacker_env_variables_for_backward_compatibility
    # @config_path = Pathname.new(ENV["SHAKAPACKER_CONFIG"] || config_path)
    # @config_hash = config_hash

    @custom_config = if custom_config
      custom_config
    else
      config_path = ENV["SHAKAPACKER_CONFIG"] ? Pathname.new(ENV["SHAKAPACKER_CONFIG"]) : Rails.root.join("config/shakapacker.yml")
      Shakapacker::Helper.parse_config_file_to_hash(config_path)
    end

    @default_config = default_config || Shakapacker::Helper.parse_config_file_to_hash(File.expand_path("../../install/config/shakapacker.yml", __FILE__))
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

    # TODO: Following commented line doesn't make sense! If we don't set
    # shakapacker_precompile in the user config file, we should fallback to
    # default config. So this is not enough to just check the value in the
    # user config.
    # return false unless config_path.exist?
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

    # TODO: Check for backward compatibility
    # See how we can get the right value for backward compatibility
    # data.fetch(key, defaults[:shakapacker_precompile])
    data.fetch(key)
  end

  private
    def data
      @data ||= config_for_env(env)
    end

    def config_for_env(env)
      full_config = HashWithIndifferentAccess.new(@default_config.deep_merge(@custom_config))

      full_config[env] || full_config[Shakapacker::DEFAULT_ENV]
    end

    def relative_path(path)
      return ".#{path}" if path.start_with?("/")

      path
    end
end

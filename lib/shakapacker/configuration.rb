require "yaml"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/hash/deep_merge"

class Shakapacker::Configuration
  class << self
    attr_accessor :installing
  end

  attr_reader :root_path, :env

  def initialize(root_path:, config_hash: {}, env:)
    @root_path = root_path
    @env = env

    # For backward compatibility
    Shakapacker.set_shakapacker_env_variables_for_backward_compatibility
    # @config_path = Pathname.new(ENV["SHAKAPACKER_CONFIG"] || config_path)
    @config_hash = config_hash
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
      @data ||= config_for_env(@config_hash, env)
    end

    def config_for_env(config, env)
      indifferent_config_hash = HashWithIndifferentAccess.new(config)
      indifferent_config_hash[env] || indifferent_config_hash[Shakapacker::DEFAULT_ENV]
    end

    def relative_path(path)
      return ".#{path}" if path.start_with?("/")

      path
    end
end

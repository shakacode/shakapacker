require "pathname"
require "shakapacker/helper"

class Shakapacker::Instance
  cattr_accessor(:logger) { ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT)) }

  attr_reader :root_path, :custom_config

  def initialize(root_path: Rails.root, custom_config: Shakapacker::Helper.parse_config_file_to_hash)
    @root_path = root_path

    # For backward compatibility
    # @config_path = Shakapacker.get_config_file_path_with_backward_compatibility(config_path)
    @custom_config = custom_config
  end

  def env
    @env ||= Shakapacker::Env.inquire self
  end

  def config
    @config ||= Shakapacker::Configuration.new(
      root_path: @root_path,
      custom_config: @custom_config,
      env: env
    )
  end

  def strategy
    @strategy ||= Shakapacker::CompilerStrategy.from_config
  end

  def compiler
    @compiler ||= Shakapacker::Compiler.new self
  end

  def dev_server
    @dev_server ||= Shakapacker::DevServer.new config
  end

  def manifest
    @manifest ||= Shakapacker::Manifest.new self
  end

  def commands
    @commands ||= Shakapacker::Commands.new self
  end

  def inlining_css?
    dev_server.inline_css? && dev_server.hmr? && dev_server.running?
  end
end

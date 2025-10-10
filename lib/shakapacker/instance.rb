require "pathname"

class Shakapacker::Instance
  cattr_accessor(:logger) { ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT)) }

  attr_reader :root_path, :config_path

  def initialize(root_path: nil, config_path: nil)
    # Use Rails.root if Rails is defined and no root_path is provided
    @root_path = root_path || (defined?(Rails) && Rails&.root) || Pathname.new(Dir.pwd)

    # Use the determined root_path to construct the default config path
    default_config_path = @root_path.join("config/shakapacker.yml")

    @config_path = Pathname.new(ENV["SHAKAPACKER_CONFIG"] || config_path || default_config_path)
  end

  def env
    @env ||= Shakapacker::Env.inquire self
  end

  def config
    @config ||= Shakapacker::Configuration.new(
      root_path: root_path,
      config_path: config_path,
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

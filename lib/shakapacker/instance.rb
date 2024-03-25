require "pathname"

class Shakapacker::Instance
  cattr_accessor(:logger) { ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT)) }

  attr_reader :root_path, :config_path

  def initialize(root_path: Rails.root, config_path: Rails.root.join("config/shakapacker.yml"))
    @root_path = root_path
    @config_path = Pathname.new(ENV["SHAKAPACKER_CONFIG"] || config_path)
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

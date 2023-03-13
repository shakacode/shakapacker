require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/string/inquiry"
require "active_support/logger"
require "active_support/tagged_logging"

module Shakapacker
  extend self

  DEFAULT_ENV = "production".freeze

  def instance=(instance)
    @instance = instance
  end

  def instance
    @instance ||= Shakapacker::Instance.new
  end

  def with_node_env(env)
    original = ENV["NODE_ENV"]
    ENV["NODE_ENV"] = env
    yield
  ensure
    ENV["NODE_ENV"] = original
  end

  def ensure_log_goes_to_stdout
    old_logger = Shakapacker.logger
    Shakapacker.logger = Logger.new(STDOUT)
    yield
  ensure
    Shakapacker.logger = old_logger
  end

  delegate :logger, :logger=, :env, :inlining_css?, to: :instance
  delegate :config, :compiler, :manifest, :commands, :dev_server, to: :instance
  delegate :bootstrap, :clean, :clobber, :compile, to: :commands
end

require "shakapacker/instance"
require "shakapacker/env"
require "shakapacker/configuration"
require "shakapacker/manifest"
require "shakapacker/compiler"
require "shakapacker/commands"
require "shakapacker/dev_server"

require "shakapacker/railtie" if defined?(Rails)

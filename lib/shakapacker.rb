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

require_relative "shakapacker/instance"
require_relative "shakapacker/env"
require_relative "shakapacker/configuration"
require_relative "shakapacker/manifest"
require_relative "shakapacker/compiler"
require_relative "shakapacker/commands"
require_relative "shakapacker/dev_server"
require_relative "shakapacker/deprecation_helper"

require_relative "shakapacker/railtie" if defined?(Rails)

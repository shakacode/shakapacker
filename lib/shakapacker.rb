require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/string/inquiry"
require "active_support/logger"
require "active_support/tagged_logging"

module Shakapacker
  extend self

  DEFAULT_ENV = "development".freeze
  # Environments that use their RAILS_ENV value for NODE_ENV
  # All other environments (production, staging, etc.) use "production" for webpack optimizations
  DEV_TEST_ENVS = %w[development test].freeze

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

  # Set NODE_ENV based on RAILS_ENV if not already set
  # - development/test environments use their RAILS_ENV value
  # - all other environments (production, staging, etc.) use "production" for webpack optimizations
  def ensure_node_env!
    ENV["NODE_ENV"] ||= DEV_TEST_ENVS.include?(ENV["RAILS_ENV"]) ? ENV["RAILS_ENV"] : "production"
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
require_relative "shakapacker/doctor"
require_relative "shakapacker/deprecation_helper"

require_relative "shakapacker/railtie" if defined?(Rails)

# frozen_string_literal: true

require "rails/generators"
require_relative "generator_helper"

module Shakapacker
  module Generators
    class DevTestsGenerator < Rails::Generators::Base
      include GeneratorHelper
      Rails::Generators.hide_namespace(namespace)
      source_root(File.expand_path("templates/dev_tests", __dir__))
    end
  end
end

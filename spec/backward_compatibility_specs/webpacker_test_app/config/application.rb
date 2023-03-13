require "action_controller/railtie"
require "action_view/railtie"
require "shakapacker"

module WebpackerTestApp
  class Application < ::Rails::Application
    config.secret_key_base = "abcdef"
    config.eager_load = true
    config.active_support.test_order = :sorted
  end
end

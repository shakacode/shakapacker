require_relative "./test_app/config/environment"

Rails.env = "production"

Shakapacker.instance = ::Shakapacker::Instance.new

def reloaded_config
  Shakapacker.instance.instance_variable_set(:@env, nil)
  Shakapacker.instance.instance_variable_set(:@config, nil)
  Shakapacker.instance.instance_variable_set(:@dev_server, nil)
  Shakapacker.env
  Shakapacker.config
  Shakapacker.dev_server
end

def with_rails_env(env)
  original = Rails.env
  Rails.env = ActiveSupport::StringInquirer.new(env)
  reloaded_config
  yield
ensure
  Rails.env = ActiveSupport::StringInquirer.new(original)
  reloaded_config
end

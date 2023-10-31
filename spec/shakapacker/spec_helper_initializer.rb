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

# Temportarily set env variables to a custom value
#
# Params
# +custom_env_hash+:: A hash with key:value for each custom env.
#                     Keys could be string or symbol
def with_env_variable(custom_env_hash)
  original_env = {}
  custom_env_hash.each do |key, new_value|
    upcased_key = key.to_s.upcase
    original_env[upcased_key] = new_value
    ENV[upcased_key] = new_value
  end

  yield
ensure
  original_env.each do |key, original_value|
    ENV[key] = original_value
  end
end

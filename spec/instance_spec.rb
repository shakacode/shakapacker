require_relative "spec_helper_initializer"

describe "Shakapacker::Instance" do
  before :all do
    ENV.delete("WEBPACKER_CONFIG")
    ENV.delete("SHAKAPACKER_CONFIG")
    Shakapacker.instance = Shakapacker::Instance.new
  end

  after :all do
    ENV.delete("WEBPACKER_CONFIG")
    ENV.delete("SHAKAPACKER_CONFIG")
    Shakapacker.instance = Shakapacker::Instance.new
  end

  # TODO: This test is not complete. It doesn't work properly in other environments
  # For now, this is an step to improve tests for new Shakapacker interface.
  it "accepts config hash in production environment" do
    config = {
      production: {
        source_path: "custom_path_value"
      }
    }

    with_rails_env("production") do
      Shakapacker.instance = Shakapacker::Instance.new(config_hash: config)
      expect(Shakapacker.config.source_path.to_s).to match /custom_path_value$/
    end
  end
end

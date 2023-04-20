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

  it "uses default config file if no configuration passed" do
    with_rails_env("development") do
      Shakapacker.instance = Shakapacker::Instance.new
      expect(Shakapacker.config.source_path.to_s).to match /app\/javascript$/
      expect(Shakapacker.config.source_entry_path.to_s).to match /entrypoints$/
    end
  end

  it "uses default config file if empty hash is given" do
    with_rails_env("development") do
      Shakapacker.instance = Shakapacker::Instance.new(custom_config: {})
      expect(Shakapacker.config.source_path.to_s).to match /app\/javascript$/
      expect(Shakapacker.config.source_entry_path.to_s).to match /packs$/
    end
  end

  it "accepts config hash in production environment" do
    config = {
      production: {
        source_path: "custom_path_value"
      }
    }

    with_rails_env("production") do
      Shakapacker.instance = Shakapacker::Instance.new(custom_config: config)
      expect(Shakapacker.config.source_path.to_s).to match /custom_path_value$/
    end
  end

  it "accepts config hash in development environment" do
    config = {
      development: {
        source_path: "custom_path_value"
      }
    }

    with_rails_env("development") do
      Shakapacker.instance = Shakapacker::Instance.new(custom_config: config)
      expect(Shakapacker.config.source_path.to_s).to match /custom_path_value$/
    end
  end
end

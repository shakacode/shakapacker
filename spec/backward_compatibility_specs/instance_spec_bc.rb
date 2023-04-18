require_relative "spec_helper_initializer"

describe "Webpacker::Instance" do
  before :each do
    ENV.delete("WEBPACKER_CONFIG")
    ENV.delete("SHAKAPACKER_CONFIG")
    Webpacker.instance = Webpacker::Instance.new
  end

  after :each do
    ENV.delete("WEBPACKER_CONFIG")
    ENV.delete("SHAKAPACKER_CONFIG")
    Webpacker.instance = Webpacker::Instance.new
  end

  it "uses default config file if no configuration passed" do
    with_rails_env("development") do
      Webpacker.instance = Webpacker::Instance.new
      expect(Webpacker.config.source_path.to_s).to match /app\/packs$/
      expect(Webpacker.config.source_entry_path.to_s).to match /entrypoints$/
    end
  end

  it "accepts config hash in production environment" do
    config = {
      production: {
        source_path: "custom_path_value"
      }
    }

    with_rails_env("production") do
      Webpacker.instance = Webpacker::Instance.new(custom_config: config)
      expect(Webpacker.config.source_path.to_s).to match /custom_path_value$/
    end
  end

  it "accepts config hash in development environment" do
    config = {
      development: {
        source_path: "custom_path_value"
      }
    }

    with_rails_env("development") do
      Webpacker.instance = Webpacker::Instance.new(custom_config: config)
      expect(Webpacker.config.source_path.to_s).to match /custom_path_value$/
    end
  end
end

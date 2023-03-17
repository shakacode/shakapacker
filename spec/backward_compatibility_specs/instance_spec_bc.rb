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

  it "uses default config path if no env variable defined" do
    actual_config_path = Rails.root.join("config/webpacker.yml")
    expected_config_path = Webpacker.config.config_path

    expect(expected_config_path).to eq(actual_config_path)
  end

  it "uses WEBPACKER_CONFIG env variable for config file" do
    ENV["WEBPACKER_CONFIG"] = "/some/random/path.yml"

    actual_config_path = "/some/random/path.yml"
    expected_config_path = Webpacker.config.config_path.to_s

    expect(Webpacker.config.config_path.to_s).to eq("/some/random/path.yml")
  end
end

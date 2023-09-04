require_relative "spec_helper_initializer"

describe "Shakapacker::Instance" do
  before :each do
    ENV.delete("WEBPACKER_CONFIG")
    ENV.delete("SHAKAPACKER_CONFIG")
    Shakapacker.instance = Shakapacker::Instance.new
  end

  after :each do
    ENV.delete("WEBPACKER_CONFIG")
    ENV.delete("SHAKAPACKER_CONFIG")
    Shakapacker.instance = Shakapacker::Instance.new
  end

  it "uses the default config path if no env variable defined" do
    actual_config_path = Rails.root.join("config/shakapacker.yml")
    expected_config_path = Shakapacker.config.config_path

    expect(expected_config_path).to eq(actual_config_path)
  end

  it "uses the SHAKAPACKER_CONFIG env variable for the config file path" do
    ENV["SHAKAPACKER_CONFIG"] = "/some/random/path.yml"

    actual_config_path = "/some/random/path.yml"
    expected_config_path = Shakapacker.config.config_path.to_s

    expect(expected_config_path).to eq(actual_config_path)
  end
end

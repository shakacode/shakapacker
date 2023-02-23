require_relative "spec_helper_initializer"

describe "shakapacker" do
  describe "#inline_css?" do
    let(:dev_server) { instance_double("Shakapacker::DevServer") }

    before :each do
      allow(dev_server).to receive(:host).and_return("localhost")
      allow(dev_server).to receive(:port).and_return("3035")
      allow(dev_server).to receive(:pretty?).and_return(false)
      allow(dev_server).to receive(:https?).and_return(true)
      allow(dev_server).to receive(:running?).and_return(true)
    end

    it "returns nil with disabled dev_server" do
      expect(Shakapacker.inlining_css?).to be nil
    end

    it "returns true with enabled hmr" do
      allow(dev_server).to receive(:hmr?).and_return(true)
      allow(dev_server).to receive(:inline_css?).and_return(true)

      allow(Shakapacker.instance).to receive(:dev_server).and_return(dev_server)

      expect(Shakapacker.inlining_css?).to be true
    end

    it "returns false with enabled hmr and explicitly setting inline_css to false" do
      allow(dev_server).to receive(:hmr?).and_return(true)
      allow(dev_server).to receive(:inline_css?).and_return(false)

      allow(Shakapacker.instance).to receive(:dev_server).and_return(dev_server)

      expect(Shakapacker.inlining_css?).to be false
    end
  end

  describe "configurable config" do
    before do
      @original_shakapacker_config = ENV["SHAKAPACKER_CONFIG"]
    end

    after do
      ENV["SHAKAPACKER_CONFIG"] = @original_shakapacker_config
    end

    it "allows config file to be changed based on ENV variable" do
      ENV.delete("SHAKAPACKER_CONFIG")
      Shakapacker.instance = nil
      expect(Shakapacker.config.config_path.to_s).to eq(Rails.root.join("config/shakapacker.yml").to_s)
    end

    it "allows config file to be changed based on ENV variable" do
      ENV["SHAKAPACKER_CONFIG"] = "/some/random/path.yml"
      Shakapacker.instance = nil
      expect(Shakapacker.config.config_path.to_s).to eq("/some/random/path.yml")
    end
  end

  it "has app_autoload_paths cleanup" do
    expect($test_app_autoload_paths_in_initializer).to eq []
  end
end

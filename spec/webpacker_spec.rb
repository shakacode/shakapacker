describe "Webpacker" do
  describe "#inline_css?" do
    let(:dev_server) { instance_double("Webpacker::DevServer") }

    before :each do
      allow(dev_server).to receive(:host).and_return("localhost")
      allow(dev_server).to receive(:port).and_return("3035")
      allow(dev_server).to receive(:pretty?).and_return(false)
      allow(dev_server).to receive(:https?).and_return(true)
      allow(dev_server).to receive(:running?).and_return(true)
    end

    it "returns nil with disabled dev_server" do
      expect(Webpacker.inlining_css?).to be nil
    end

    it "returns true with enabled hmr" do
      allow(dev_server).to receive(:hmr?).and_return(true)
      allow(dev_server).to receive(:inline_css?).and_return(true)

      allow(Webpacker.instance).to receive(:dev_server).and_return(dev_server)

      expect(Webpacker.inlining_css?).to be true
    end

    it "returns false with enabled hmr and explicitly setting inline_css to false" do
      allow(dev_server).to receive(:hmr?).and_return(true)
      allow(dev_server).to receive(:inline_css?).and_return(false)

      allow(Webpacker.instance).to receive(:dev_server).and_return(dev_server)

      expect(Webpacker.inlining_css?).to be false
    end
  end

  describe "configurable config" do
    before do
      @original_webpacker_config = ENV["WEBPACKER_CONFIG"]
    end

    after do
      ENV["WEBPACKER_CONFIG"] = @original_webpacker_config
    end

    it "allows config file to be changed based on ENV variable" do
      ENV.delete("WEBPACKER_CONFIG")
      Webpacker.instance = nil
      expect(Webpacker.config.config_path.to_s).to eq(Rails.root.join("config/webpacker.yml").to_s)
    end

    it "allows config file to be changed based on ENV variable" do
      ENV["WEBPACKER_CONFIG"] = "/some/random/path.yml"
      Webpacker.instance = nil
      expect(Webpacker.config.config_path.to_s).to eq("/some/random/path.yml")
    end
  end

  it "has app_autoload_paths cleanup" do
    expect($test_app_autoload_paths_in_initializer).to eq []
  end
end

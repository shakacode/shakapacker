require_relative "spec_helper_initializer"

describe "Shakapacker" do
  describe "#inline_css?" do
    let(:dev_server) { instance_double("Shakapacker::DevServer") }

    before :each do
      allow(dev_server).to receive(:host).and_return("localhost")
      allow(dev_server).to receive(:port).and_return("3035")
      allow(dev_server).to receive(:pretty?).and_return(false)
      allow(dev_server).to receive(:https?).and_return(true)
      allow(dev_server).to receive(:running?).and_return(true)
    end

    it "returns nil when the dev server is disabled" do
      expect(Shakapacker.inlining_css?).to be nil
    end

    it "returns true when hmr is enabled" do
      allow(dev_server).to receive(:hmr?).and_return(true)
      allow(dev_server).to receive(:inline_css?).and_return(true)

      allow(Shakapacker.instance).to receive(:dev_server).and_return(dev_server)

      expect(Shakapacker.inlining_css?).to be true
    end

    it "returns false when hmr is enabled and inline_css is explicitly set to false" do
      allow(dev_server).to receive(:hmr?).and_return(true)
      allow(dev_server).to receive(:inline_css?).and_return(false)

      allow(Shakapacker.instance).to receive(:dev_server).and_return(dev_server)

      expect(Shakapacker.inlining_css?).to be false
    end
  end

  it "automatically cleans up app_autoload_paths" do
    expect($test_app_autoload_paths_in_initializer).to eq []
  end
end

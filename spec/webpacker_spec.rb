describe "Webpacker" do
  it "accepts env as config params" do
    expect(Webpacker.config.env).to eq Rails.env
    expect(Webpacker.config.root_path).to eq Webpacker.instance.root_path
    expect(Webpacker.config.config_path).to eq Webpacker.instance.config_path

    with_rails_env("test") do
      expect(Webpacker.config.env).to eq "test"
    end
  end

  it "#inline_css? returns false with disabled dev_server" do
    expect(Webpacker.inlining_css?).to be_falsy
  end

  it "#inline_css? returns true with enabled hmr" do
    dev_server = double("dev_server")
    allow(dev_server).to receive(:host).and_return("localhost")
    allow(dev_server).to receive(:port).and_return("3035")
    allow(dev_server).to receive(:pretty?).and_return(false)
    allow(dev_server).to receive(:https?).and_return(true)
    allow(dev_server).to receive(:hmr?).and_return(true)
    allow(dev_server).to receive(:running?).and_return(true)
    allow(dev_server).to receive(:inline_css?).and_return(true)
    allow(Webpacker.instance).to receive(:dev_server).and_return(dev_server)

    expect(Webpacker.inlining_css?).to be true
  end

  it "#inline_css? returns false with enabled hmr and explicitly setting inline_css to false" do
    dev_server = double("dev_server")
    allow(dev_server).to receive(:host).and_return("localhost")
    allow(dev_server).to receive(:port).and_return("3035")
    allow(dev_server).to receive(:pretty?).and_return(false)
    allow(dev_server).to receive(:https?).and_return(true)
    allow(dev_server).to receive(:hmr?).and_return(true)
    allow(dev_server).to receive(:running?).and_return(true)
    allow(dev_server).to receive(:inline_css?).and_return(false)
    allow(Webpacker.instance).to receive(:dev_server).and_return(dev_server)

    expect(Webpacker.inlining_css?).to be_falsy
  end

  it "has app_autoload_paths cleanup" do
    expect($test_app_autoload_paths_in_initializer).to eq []
  end
end

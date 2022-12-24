describe "Compiler" do
  it "accepts custom environment variables" do
    expect(Webpacker.compiler.send(:webpack_env)["FOO"]).to be nil

    Webpacker.compiler.env["FOO"] = "BAR"
    expect(Webpacker.compiler.send(:webpack_env)["FOO"]).to eq "BAR"
  ensure
    Webpacker.compiler.env = {}
  end

  it "compiles when fresh" do
    mock = double("mock")
    allow(mock).to receive(:stale?).and_return(false)
    allow(Webpacker.compiler).to receive(:strategy).and_return(mock)

    expect(Webpacker.compiler.compile).to be_truthy
    expect(mock).to have_received(:stale?)
  end

  it "calls after_compile_hook on successful compile" do
    mock = double("mock")
    allow(mock).to receive(:stale?).and_return(true)
    allow(mock).to receive(:after_compile_hook).and_return(nil)

    status = OpenStruct.new(success?: true)

    allow(Webpacker.compiler).to receive(:strategy).and_return(mock)
    allow(Open3).to receive(:capture3).and_return([:sterr, :stdout, status])

    Webpacker.compiler.compile
    expect(mock).to have_received(:after_compile_hook)
  end

  it "calls after_compile_hook on failed compile" do
    mock = double("mock")
    allow(mock).to receive(:stale?).and_return(true)
    allow(mock).to receive(:after_compile_hook).and_return(nil)

    status = OpenStruct.new(success?: false)

    allow(Webpacker.compiler).to receive(:strategy).and_return(mock)
    allow(Open3).to receive(:capture3).and_return([:sterr, :stdout, status])

    Webpacker.compiler.compile
    expect(mock).to have_received(:after_compile_hook)
  end

  it "accepts external env variables" do
    expect(Webpacker.compiler.send(:webpack_env)["WEBPACKER_ASSET_HOST"]).to be nil
    expect(Webpacker.compiler.send(:webpack_env)["WEBPACKER_RELATIVE_URL_ROOT"]).to be nil

    ENV["WEBPACKER_ASSET_HOST"] = "foo.bar"
    ENV["WEBPACKER_RELATIVE_URL_ROOT"] = "/baz"

    expect(Webpacker.compiler.send(:webpack_env)["WEBPACKER_ASSET_HOST"]).to eq "foo.bar"
    expect(Webpacker.compiler.send(:webpack_env)["WEBPACKER_RELATIVE_URL_ROOT"]).to eq "/baz"
  end
end

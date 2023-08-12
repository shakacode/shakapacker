require_relative "spec_helper_initializer"

describe "Webpacker::Compiler" do
  it "accepts custom environment variables" do
    expect(Webpacker.compiler.send(:webpack_env)["FOO"]).to be nil

    Webpacker.compiler.env["FOO"] = "BAR"
    expect(Webpacker.compiler.send(:webpack_env)["FOO"]).to eq "BAR"
  ensure
    Webpacker.compiler.env = {}
  end

  it "returns true when fresh" do
    mocked_strategy = double("Strategy")
    expect(mocked_strategy).to receive(:stale?).and_return(false)

    expect(Webpacker.compiler).to receive(:strategy).and_return(mocked_strategy)

    expect(Webpacker.compiler.compile).to be true
  end

  it "returns true and calls after_compile_hook on successful compile" do
    mocked_strategy = spy("Strategy")
    expect(mocked_strategy).to receive(:stale?).and_return(true)

    allow(Webpacker.compiler).to receive(:strategy).and_return(mocked_strategy)

    status = OpenStruct.new(success?: true)
    allow(Open3).to receive(:capture3).and_return([:stderr, :stdout, status])

    expect(Webpacker.compiler.compile).to be true
    expect(mocked_strategy).to have_received(:after_compile_hook)
  end

  it "returns false and calls after_compile_hook on failed compile" do
    mocked_strategy = spy("Strategy")
    allow(mocked_strategy).to receive(:stale?).and_return(true)
    allow(mocked_strategy).to receive(:after_compile_hook)

    allow(Webpacker.compiler).to receive(:strategy).and_return(mocked_strategy)

    status = OpenStruct.new(success?: false)
    allow(Open3).to receive(:capture3).and_return([:stderr, :stdout, status])

    expect(Webpacker.compiler.compile).to be false
    expect(mocked_strategy).to have_received(:after_compile_hook)
  end

  it "accepts external env variables" do
    expect(Webpacker.compiler.send(:webpack_env)["SHAKAPACKER_ASSET_HOST"]).to be nil
    expect(Webpacker.compiler.send(:webpack_env)["SHAKAPACKER_RELATIVE_URL_ROOT"]).to be nil

    ENV["WEBPACKER_ASSET_HOST"] = "foo.bar"
    ENV["WEBPACKER_RELATIVE_URL_ROOT"] = "/baz"

    expect(Webpacker.compiler.send(:webpack_env)["SHAKAPACKER_ASSET_HOST"]).to eq "foo.bar"
    expect(Webpacker.compiler.send(:webpack_env)["SHAKAPACKER_RELATIVE_URL_ROOT"]).to eq "/baz"
  end
end

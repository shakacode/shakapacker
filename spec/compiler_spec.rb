describe "Shakapacker::Compiler" do
  it "accepts custom environment variables" do
    expect(Shakapacker.compiler.send(:webpack_env)["FOO"]).to be nil

    Shakapacker.compiler.env["FOO"] = "BAR"
    expect(Shakapacker.compiler.send(:webpack_env)["FOO"]).to eq "BAR"
  ensure
    Shakapacker.compiler.env = {}
  end

  it "returns true when fresh" do
    mocked_strategy = double("Strategy")
    expect(mocked_strategy).to receive(:stale?).and_return(false)

    expect(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

    expect(Shakapacker.compiler.compile).to be true
  end

  it "returns true and calls after_compile_hook on successful compile" do
    mocked_strategy = spy("Strategy")
    expect(mocked_strategy).to receive(:stale?).and_return(true)

    allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

    status = OpenStruct.new(success?: true)
    allow(Open3).to receive(:capture3).and_return([:sterr, :stdout, status])

    expect(Shakapacker.compiler.compile).to be true
    expect(mocked_strategy).to have_received(:after_compile_hook)
  end

  it "returns false and calls after_compile_hook on failed compile" do
    mocked_strategy = spy("Strategy")
    allow(mocked_strategy).to receive(:stale?).and_return(true)
    allow(mocked_strategy).to receive(:after_compile_hook)

    allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

    status = OpenStruct.new(success?: false)
    allow(Open3).to receive(:capture3).and_return([:sterr, :stdout, status])

    expect(Shakapacker.compiler.compile).to be false
    expect(mocked_strategy).to have_received(:after_compile_hook)
  end

  it "accepts external env variables" do
    expect(Shakapacker.compiler.send(:webpack_env)["SHAKAPACKER_ASSET_HOST"]).to be nil
    expect(Shakapacker.compiler.send(:webpack_env)["SHAKAPACKER_RELATIVE_URL_ROOT"]).to be nil

    ENV["SHAKAPACKER_ASSET_HOST"] = "foo.bar"
    ENV["SHAKAPACKER_RELATIVE_URL_ROOT"] = "/baz"

    expect(Shakapacker.compiler.send(:webpack_env)["SHAKAPACKER_ASSET_HOST"]).to eq "foo.bar"
    expect(Shakapacker.compiler.send(:webpack_env)["SHAKAPACKER_RELATIVE_URL_ROOT"]).to eq "/baz"
  end
end

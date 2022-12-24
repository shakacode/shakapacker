describe "Webpacker::MtimeStrategy" do
  before :all do
    @mtime_strategy = Webpacker::MtimeStrategy.new
    @manifest_timestamp = Time.parse("2021-01-01 12:34:56 UTC")
  end

  def with_stubs(latest_timestamp:, manifest_exists: true)
    allow(@mtime_strategy).to receive(:latest_modified_timestamp).and_return(latest_timestamp)
    allow(FileTest).to receive(:exist?).and_return(manifest_exists)
    allow(File).to receive(:mtime).and_return(@manifest_timestamp)
    yield
  end

  it "#stale? returns true when manifest is missing" do
    latest_timestamp = @manifest_timestamp + 3600

    with_stubs(latest_timestamp: latest_timestamp.to_i, manifest_exists: false) do
      expect(@mtime_strategy.stale?).to be true
    end
  end

  it "#stale? returns true when manifest is older" do
    latest_timestamp = @manifest_timestamp + 3600

    with_stubs(latest_timestamp: latest_timestamp.to_i) do
      expect(@mtime_strategy.stale?).to be true
    end
  end

  it "#fresh? returns true when manifest is new" do
    latest_timestamp = @manifest_timestamp - 3600

    with_stubs(latest_timestamp: latest_timestamp.to_i) do
      expect(@mtime_strategy.fresh?).to be true
    end
  end
end

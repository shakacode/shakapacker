describe "Shakapacker::MtimeStrategy" do
  let(:mtime_strategy) { Shakapacker::MtimeStrategy.new }
  let(:manifest_timestamp) { Time.parse("2021-01-01 12:34:56 UTC") }

  describe "#fresh?" do
    it "returns false when manifest is missing" do
      latest_timestamp = manifest_timestamp + 3600

      with_stubs(latest_timestamp: latest_timestamp.to_i, manifest_exists: false) do
        expect(mtime_strategy.fresh?).to be false
      end
    end

    it "returns false when manifest is older" do
      latest_timestamp = manifest_timestamp + 3600

      with_stubs(latest_timestamp: latest_timestamp.to_i) do
        expect(mtime_strategy.fresh?).to be false
      end
    end

    it "returns true when manifest is new" do
      latest_timestamp = manifest_timestamp - 3600

      with_stubs(latest_timestamp: latest_timestamp.to_i) do
        expect(mtime_strategy.fresh?).to be true
      end
    end
  end

  describe "#stale?" do
    it "returns false when #fresh? is true" do
      expect(mtime_strategy).to receive(:fresh?).and_return(true)

      expect(mtime_strategy.stale?).to be false
    end

    it "returns true when #fresh? is false" do
      expect(mtime_strategy).to receive(:fresh?).and_return(false)

      expect(mtime_strategy.stale?).to be true
    end
  end

  private

    def with_stubs(latest_timestamp:, manifest_exists: true)
      allow(mtime_strategy).to receive(:latest_modified_timestamp).and_return(latest_timestamp)
      allow(FileTest).to receive(:exist?).and_return(manifest_exists)
      allow(File).to receive(:mtime).and_return(manifest_timestamp)
      yield
    end
end

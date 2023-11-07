require_relative "spec_helper_initializer"

describe "DigestStrategy" do
  def remove_compilation_digest_path
    @digest_strategy.send(:compilation_digest_path).tap do |path|
      path.delete if path.exist?
    end
  end

  before :all do
    @digest_strategy = Shakapacker::DigestStrategy.new
    remove_compilation_digest_path
  end

  after :all do
    remove_compilation_digest_path
  end

  it "is not fresh before compilation" do
    expect(@digest_strategy.stale?).to be true
    expect(@digest_strategy.fresh?).to be_falsy
  end

  it "is fresh after compilation" do
    @digest_strategy.after_compile_hook

    expect(@digest_strategy.stale?).to be false
    expect(@digest_strategy.fresh?).to be true
  end

  it "is stale when host changes" do
    allow(ENV).to receive(:fetch).with("SHAKAPACKER_ASSET_HOST", nil).and_return("old-host")
    # Record the digests for old-host
    @digest_strategy.after_compile_hook

    allow(ENV).to receive(:fetch).with("SHAKAPACKER_ASSET_HOST", nil).and_return("new-host")
    expect(@digest_strategy.stale?).to be true
    expect(@digest_strategy.fresh?).to be_falsey
  end

  it "generates correct compilation_digest_path" do
    allow(ENV).to receive(:fetch).with("SHAKAPACKER_ASSET_HOST", nil).and_return("custom-path")

    actual_path = @digest_strategy.send(:compilation_digest_path).basename.to_s
    host_hash = Digest::SHA1.hexdigest("custom-path")
    expected_path = "last-compilation-digest-#{Shakapacker.env}"

    expect(actual_path).to eq expected_path
  end

  it "generates correct compilation_digest_path without the digest of the asset host if asset host is not set" do
    allow(ENV).to receive(:fetch).with("SHAKAPACKER_ASSET_HOST", nil).and_return(nil)

    actual_path = @digest_strategy.send(:compilation_digest_path).basename.to_s
    expected_path = "last-compilation-digest-#{Shakapacker.env}"

    expect(actual_path).to eq expected_path
  end
end

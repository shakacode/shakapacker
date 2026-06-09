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

  it "uses the provided instance cache path and env for compilation_digest_path" do
    cache_path = Pathname.new("/tmp/custom-shakapacker-cache")
    custom_config = double("config", cache_path: cache_path)
    custom_instance = double("instance", config: custom_config, env: "custom-env")
    digest_strategy = Shakapacker::DigestStrategy.new(custom_instance)

    expect(digest_strategy.send(:compilation_digest_path)).to eq cache_path.join("last-compilation-digest-custom-env")
  end

  it "uses the provided instance asset_host in watched_files_digest" do
    custom_config = double(
      "config",
      root_path: Shakapacker.config.root_path,
      source_path: "missing-source-path",
      additional_paths: [],
      asset_host: "instance-host"
    )
    custom_instance = double("instance", config: custom_config, env: Shakapacker.env)
    digest_strategy = Shakapacker::DigestStrategy.new(custom_instance)

    allow(Dir).to receive(:[]).and_return([])
    allow(Shakapacker.config).to receive(:asset_host).and_return("global-host")

    expect(digest_strategy.send(:watched_files_digest)).to eq Digest::SHA1.hexdigest("instance-host")
  end
end

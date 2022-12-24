describe "Configuration" do
  before :context do
    @config = Webpacker::Configuration.new(
      root_path: Pathname.new(File.expand_path("test_app", __dir__)),
      config_path: Pathname.new(File.expand_path("./test_app/config/webpacker.yml", __dir__)),
      env: "production"
    )
  end

  it "returns correct source_path" do
    source_path = File.expand_path File.join(File.dirname(__FILE__), "test_app/app/packs").to_s
    expect(@config.source_path.to_s).to eq source_path
  end

  it "returns correct source_entry_path" do
    source_entry_path = File.expand_path File.join(File.dirname(__FILE__), "test_app/app/packs", "entrypoints").to_s
    expect(@config.source_entry_path.to_s).to eq source_entry_path
  end

  it "returns correct public_root_path" do
    public_root_path = File.expand_path File.join(File.dirname(__FILE__), "test_app/public").to_s
    expect(@config.public_path.to_s).to eq public_root_path
  end

  it "returns correct public_output_path" do
    public_output_path = File.expand_path File.join(File.dirname(__FILE__), "test_app/public/packs").to_s
    expect(@config.public_output_path.to_s).to eq public_output_path

    public_root_config = Webpacker::Configuration.new(
      root_path: @config.root_path,
      config_path: Pathname.new(File.expand_path("./test_app/config/webpacker_public_root.yml", __dir__)),
      env: "production"
    )

    public_output_path = File.expand_path File.join(File.dirname(__FILE__), "public/packs").to_s
    expect(public_root_config.public_output_path.to_s).to eq public_output_path
  end

  it "returns correct public_manifest_path" do
    public_manifest_path = File.expand_path File.join(File.dirname(__FILE__), "test_app/public/packs", "manifest.json").to_s
    expect(@config.public_manifest_path.to_s).to eq public_manifest_path
  end

  it "returns correct manifest_path" do
    manifest_path = File.expand_path File.join(File.dirname(__FILE__), "test_app/public/packs", "manifest.json").to_s
    expect(@config.manifest_path.to_s).to eq manifest_path

    @manifest_config = Webpacker::Configuration.new(
      root_path: @config.root_path,
      config_path: Pathname.new(File.expand_path("./test_app/config/webpacker_manifest_path.yml", __dir__)),
      env: "production"
    )

    manifest_path = File.expand_path File.join(File.dirname(__FILE__), "test_app/app/packs", "manifest.json").to_s
    expect(@manifest_config.manifest_path.to_s).to eq manifest_path
  end

  it "returns correct cache_path" do
    cache_path = File.expand_path File.join(File.dirname(__FILE__), "test_app/tmp/webpacker").to_s
    expect(@config.cache_path.to_s).to eq cache_path
  end

  it "returns correct additional_paths" do
    expect(@config.additional_paths).to eq ["app/assets", "/etc/yarn", "some.config.js", "app/elm"]
  end

  it "returns correct cache_manifest?" do
    expect(@config.cache_manifest?).to be true

    with_rails_env("development") do
      expect(Webpacker.config.cache_manifest?).to be false
    end

    with_rails_env("test") do
      expect(Webpacker.config.cache_manifest?).to be false
    end
  end

  it "returns correct compile?" do
    expect(@config.compile?).to be false

    with_rails_env("development") do
      expect(Webpacker.config.compile?).to be true
    end

    with_rails_env("test") do
      expect(Webpacker.config.compile?).to be true
    end
  end

  it "returns correct nested_entries?" do
    expect(@config.nested_entries?).to be false

    with_rails_env("development") do
      expect(Webpacker.config.nested_entries?).to be false
    end

    with_rails_env("test") do
      expect(Webpacker.config.nested_entries?).to be false
    end
  end

  it "returns correct ensure_consistent_versioning?" do
    expect(@config.ensure_consistent_versioning?).to be false

    with_rails_env("development") do
      expect(Webpacker.config.ensure_consistent_versioning?).to be true
    end

    with_rails_env("test") do
      expect(Webpacker.config.ensure_consistent_versioning?).to be false
    end
  end

  it "returns correct webpacker_precompile" do
    expect(@config.webpacker_precompile?).to be true

    ENV["WEBPACKER_PRECOMPILE"] = "no"
    expect(Webpacker.config.webpacker_precompile?).to be false

    ENV["WEBPACKER_PRECOMPILE"] = "yes"
    expect(Webpacker.config.webpacker_precompile?).to be true

    ENV["WEBPACKER_PRECOMPILE"] = "false"
    expect(Webpacker.config.webpacker_precompile?).to be false

    ENV["WEBPACKER_PRECOMPILE"] = "true"
    expect(Webpacker.config.webpacker_precompile?).to be true

    ENV["WEBPACKER_PRECOMPILE"] = "n"
    expect(Webpacker.config.webpacker_precompile?).to be false

    ENV["WEBPACKER_PRECOMPILE"] = "y"
    expect(Webpacker.config.webpacker_precompile?).to be true

    ENV["WEBPACKER_PRECOMPILE"] = "f"
    expect(Webpacker.config.webpacker_precompile?).to be false

    ENV["WEBPACKER_PRECOMPILE"] = "t"
    expect(Webpacker.config.webpacker_precompile?).to be true

    @no_precompile_config = Webpacker::Configuration.new(
      root_path: @config.root_path,
      config_path: Pathname.new(File.expand_path("./test_app/config/webpacker_no_precompile.yml", __dir__)),
      env: "production"
    )

    expect(@no_precompile_config.webpacker_precompile?).to be true

    ENV["WEBPACKER_PRECOMPILE"] = nil

    expect(@no_precompile_config.webpacker_precompile?).to be false

    @invalid_path_config = Webpacker::Configuration.new(
      root_path: @config.root_path,
      config_path: Pathname.new(File.expand_path("./test_app/config/invalid_path.yml", __dir__)),
      env: "default"
    )

    expect(@invalid_path_config.webpacker_precompile?).to be false
  end

  it "falls back to bundled config with the same name for standard environments" do
    no_default_config = Webpacker::Configuration.new(
      root_path: @config.root_path,
      config_path: Pathname.new(File.expand_path("./test_app/config/webpacker_defaults_fallback.yml", __dir__)),
      env: "default"
    )

    expect(no_default_config.cache_manifest?).to be false # fall back to "default" config from bundled file
    expect(no_default_config.webpacker_precompile?).to be false # use "default" config from custom file
  end

  it "falls back to bundled production config for custom environments" do
    no_env_config = Webpacker::Configuration.new(
      root_path: @config.root_path,
      config_path: Pathname.new(File.expand_path("./test_app/config/webpacker_defaults_fallback.yml", __dir__)),
      env: "staging"
    )

    expect(no_env_config.cache_manifest?).to be true # fall back to "production" config from bundled file
    expect(no_env_config.webpacker_precompile?).to be false # use "staging" config from custom file
  end
end

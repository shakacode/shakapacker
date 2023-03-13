describe "Shakapacker::Configuration" do
  ROOT_PATH = Pathname.new(File.expand_path("test_app", __dir__))

  context "with standard shakapacker.yml" do
    let(:config) do
      Shakapacker::Configuration.new(
        root_path: ROOT_PATH,
        config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker.yml", __dir__)),
        env: "production"
      )
    end

    it "#source_path returns correct path" do
      source_path = File.expand_path File.join(File.dirname(__FILE__), "test_app/app/packs").to_s
      expect(config.source_path.to_s).to eq source_path
    end

    it "#source_entry_path returns correct path" do
      source_entry_path = File.expand_path File.join(File.dirname(__FILE__), "test_app/app/packs", "entrypoints").to_s
      expect(config.source_entry_path.to_s).to eq source_entry_path
    end

    it "#public_root_path returns correct path" do
      public_root_path = File.expand_path File.join(File.dirname(__FILE__), "test_app/public").to_s
      expect(config.public_path.to_s).to eq public_root_path
    end

    it "#public_output_path returns correct path" do
      public_output_path = File.expand_path File.join(File.dirname(__FILE__), "test_app/public/packs").to_s
      expect(config.public_output_path.to_s).to eq public_output_path
    end

    it "#public_manifest_path returns correct path" do
      public_manifest_path = File.expand_path File.join(File.dirname(__FILE__), "test_app/public/packs", "manifest.json").to_s
      expect(config.public_manifest_path.to_s).to eq public_manifest_path
    end

    it "#manifest_path returns correct path" do
      manifest_path = File.expand_path File.join(File.dirname(__FILE__), "test_app/public/packs", "manifest.json").to_s
      expect(config.manifest_path.to_s).to eq manifest_path
    end

    it "#cache_path returns correct path" do
      cache_path = File.expand_path File.join(File.dirname(__FILE__), "test_app/tmp/shakapacker").to_s
      expect(config.cache_path.to_s).to eq cache_path
    end

    it "#additional_paths returns correct path" do
      expect(config.additional_paths).to eq ["app/assets", "/etc/yarn", "some.config.js", "app/elm"]
    end

    describe "#cache_manifest?" do
      it "returns true in production environment" do
        expect(config.cache_manifest?).to be true
      end

      it "returns false in developemnt environemnt" do
        with_rails_env("development") do
          expect(Shakapacker.config.cache_manifest?).to be false
        end
      end

      it "returns false in test environment" do
        with_rails_env("test") do
          expect(Shakapacker.config.cache_manifest?).to be false
        end
      end
    end

    describe "#compile?" do
      it "returns false in production environment" do
        expect(config.compile?).to be false
      end

      it "returns true in developemnt environemnt" do
        with_rails_env("development") do
          expect(Shakapacker.config.compile?).to be true
        end
      end

      it "returns true in test environemnt" do
        with_rails_env("test") do
          expect(Shakapacker.config.compile?).to be true
        end
      end
    end

    describe "#nested_entries?" do
      it "returns false in production environment" do
        expect(config.nested_entries?).to be false
      end

      it "returns false in development environment" do
        with_rails_env("development") do
          expect(Shakapacker.config.nested_entries?).to be false
        end
      end

      it "returns false in test environment" do
        with_rails_env("test") do
          expect(Shakapacker.config.nested_entries?).to be false
        end
      end
    end

    describe "#ensure_consistent_versioning?" do
      it "returns false in production environment" do
        expect(config.ensure_consistent_versioning?).to be false
      end

      it "returns true in development environment" do
        with_rails_env("development") do
          expect(Shakapacker.config.ensure_consistent_versioning?).to be true
        end
      end

      it "returns false in test environment" do
        with_rails_env("test") do
          expect(Shakapacker.config.ensure_consistent_versioning?).to be false
        end
      end
    end

    describe "#shakapacker_precompile?" do
      before :each do
        ENV["SHAKAPACKER_PRECOMPILE"] = nil
      end

      subject { config.shakapacker_precompile? }

      it "returns true when SHAKAPACKER_PRECOMPILE is unset" do
        is_expected.to be true
      end

      it "returns false when SHAKAPACKER_PRECOMPILE sets to no" do
        ENV["SHAKAPACKER_PRECOMPILE"] = "no"
        is_expected.to be false
      end

      it "returns true when SHAKAPACKER_PRECOMPILE sets to yes" do
        ENV["SHAKAPACKER_PRECOMPILE"] = "yes"
        is_expected.to be true
      end

      it "returns false when SHAKAPACKER_PRECOMPILE sets to false" do
        ENV["SHAKAPACKER_PRECOMPILE"] = "false"
        is_expected.to be false
      end

      it "returns true when SHAKAPACKER_PRECOMPILE sets to true" do
        ENV["SHAKAPACKER_PRECOMPILE"] = "true"
        is_expected.to be true
      end

      it "returns false when SHAKAPACKER_PRECOMPILE sets to n" do
        ENV["SHAKAPACKER_PRECOMPILE"] = "n"
        is_expected.to be false
      end

      it "returns true when SHAKAPACKER_PRECOMPILE sets to y" do
        ENV["SHAKAPACKER_PRECOMPILE"] = "y"
        is_expected.to be true
      end

      it "returns false when SHAKAPACKER_PRECOMPILE sets to f" do
        ENV["SHAKAPACKER_PRECOMPILE"] = "f"
        is_expected.to be false
      end

      it "returns true when SHAKAPACKER_PRECOMPILE sets to t" do
        ENV["SHAKAPACKER_PRECOMPILE"] = "t"
        is_expected.to be true
      end
    end
  end

  context "with shakapacker config file containing public_output_path entry" do
    config = Shakapacker::Configuration.new(
      root_path: ROOT_PATH,
      config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker_public_root.yml", __dir__)),
      env: "production"
    )

    it "#public_output_path returns correct path" do
      expected_public_output_path = File.expand_path File.join(File.dirname(__FILE__), "public/packs").to_s
      expect(config.public_output_path.to_s).to eq expected_public_output_path
    end
  end

  context "with shakapacker config file containing manifext_path entry" do
    config = Shakapacker::Configuration.new(
      root_path: ROOT_PATH,
      config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker_manifest_path.yml", __dir__)),
      env: "production"
    )

    it "#manifest_path returns correct expected value" do
      expected_manifest_path = File.expand_path File.join(File.dirname(__FILE__), "test_app/app/packs", "manifest.json").to_s
      expect(config.manifest_path.to_s).to eq expected_manifest_path
    end
  end

  context "with shakapacker_precompile entry set to false" do
    describe "#shakapacker_precompile?" do
      before :each do
        ENV["SHAKAPACKER_PRECOMPILE"] = nil
      end

      let(:config) {
        Shakapacker::Configuration.new(
          root_path: ROOT_PATH,
          config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker_no_precompile.yml", __dir__)),
          env: "production"
        )
      }

      subject { config.shakapacker_precompile? }

      it "returns false with unset SHAKAPACKER_PRECOMPILE" do
        expect(subject).to be false
      end

      it "returns true with SHAKAPACKER_PRECOMPILE set to true" do
        ENV["SHAKAPACKER_PRECOMPILE"] = "true"
        expect(subject).to be true
      end

      it "returns false with SHAKAPACKER_PRECOMPILE set to nil" do
        ENV["SHAKAPACKER_PRECOMPILE"] = nil
        expect(subject).to be false
      end
    end
  end

  context "with shakapacker config file containing invalid path" do
    config = Shakapacker::Configuration.new(
      root_path: ROOT_PATH,
      config_path: Pathname.new(File.expand_path("./test_app/config/invalid_path.yml", __dir__)),
      env: "default"
    )

    it "#shakapacker_precompile? returns false" do
      expect(config.shakapacker_precompile?).to be false
    end
  end

  context "with shakapacker config file with defaults fallback" do
    let(:config) do
      Shakapacker::Configuration.new(
        root_path: ROOT_PATH,
        config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker_defaults_fallback.yml", __dir__)),
        env: "default"
      )
    end

    it "#cache_manifest? falls back to 'default' config from bundled file" do
      expect(config.cache_manifest?).to be false
    end

    it "#shakapacker_precompile? uses 'default' config from custom file" do
      expect(config.shakapacker_precompile?).to be false
    end
  end

  context "falls back to bundled production config for custom environments" do
    let(:config) do
      Shakapacker::Configuration.new(
        root_path: ROOT_PATH,
        config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker_defaults_fallback.yml", __dir__)),
        env: "staging"
      )
    end

    it "#cache_manifest? fall back to 'production' config from bundled file" do
      expect(config.cache_manifest?).to be true
    end
    it "#shakapacker_precompile? use 'staging' config from custom file" do
      expect(config.shakapacker_precompile?).to be false
    end
  end
end

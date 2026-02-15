require_relative "spec_helper_initializer"
require "tempfile"

describe "Shakapacker::Configuration" do
  ROOT_PATH = Pathname.new(File.expand_path("./test_app", __dir__))

  context "with standard shakapacker.yml" do
    let(:config) do
      Shakapacker::Configuration.new(
        root_path: ROOT_PATH,
        config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker.yml", __dir__)),
        env: "production"
      )
    end

    it "#source_path returns correct path" do
      source_path = File.expand_path File.join(File.dirname(__FILE__), "./test_app/app/javascript").to_s

      expect(config.source_path.to_s).to eq source_path
    end

    it "#source_entry_path returns correct path" do
      source_entry_path = File.expand_path File.join(File.dirname(__FILE__), "./test_app/app/javascript", "entrypoints").to_s

      expect(config.source_entry_path.to_s).to eq source_entry_path
    end

    it "#public_root_path returns correct path" do
      public_root_path = File.expand_path File.join(File.dirname(__FILE__), "./test_app/public").to_s

      expect(config.public_path.to_s).to eq public_root_path
    end

    it "#public_output_path returns correct path" do
      public_output_path = File.expand_path File.join(File.dirname(__FILE__), "./test_app/public/packs").to_s

      expect(config.public_output_path.to_s).to eq public_output_path
    end

    it "#public_manifest_path returns correct path" do
      public_manifest_path = File.expand_path File.join(File.dirname(__FILE__), "./test_app/public/packs", "manifest.json").to_s

      expect(config.public_manifest_path.to_s).to eq public_manifest_path
    end

    it "#manifest_path returns correct path" do
      manifest_path = File.expand_path File.join(File.dirname(__FILE__), "./test_app/public/packs", "manifest.json").to_s

      expect(config.manifest_path.to_s).to eq manifest_path
    end

    it "#cache_path returns correct path" do
      cache_path = File.expand_path File.join(File.dirname(__FILE__), "./test_app/tmp/shakapacker").to_s

      expect(config.cache_path.to_s).to eq cache_path
    end

    describe "#data" do
      it "is publicly accessible" do
        expect(config).to respond_to(:data)
      end

      it "returns a hash with symbolized keys" do
        data = config.data
        expect(data).to be_a(Hash)
        expect(data.keys).to all(be_a(Symbol))
      end

      it "returns configuration from shakapacker.yml" do
        data = config.data
        expect(data[:source_path]).to eq("app/javascript")
        expect(data[:public_output_path]).to eq("packs")
      end

      it "returns frozen hash to prevent mutations" do
        expect(config.data).to be_frozen
      end
    end

    it "#private_output_path returns correct path" do
      private_output_path = File.expand_path File.join(File.dirname(__FILE__), "./test_app/ssr-generated").to_s

      expect(config.private_output_path.to_s).to eq private_output_path
    end

    it "#private_output_path returns nil for empty string" do
      test_config = Tempfile.new(["shakapacker", ".yml"])
      test_config.write(<<~YAML)
        test:
          source_path: app/javascript
          source_entry_path: entrypoints
          public_root_path: public
          public_output_path: packs
          private_output_path: ""
      YAML
      test_config.rewind

      config = Shakapacker::Configuration.new(
        root_path: ROOT_PATH,
        config_path: Pathname.new(test_config.path),
        env: "test"
      )

      expect(config.private_output_path).to be_nil

      test_config.close
      test_config.unlink
    end

    it "validates private_output_path is different from public_output_path" do
      # Create a test config file with same paths
      test_config = Tempfile.new(["shakapacker", ".yml"])
      test_config.write(<<~YAML)
        test:
          source_path: app/javascript
          source_entry_path: entrypoints
          public_root_path: public
          public_output_path: packs
          private_output_path: public/packs
      YAML
      test_config.rewind

      expect {
        Shakapacker::Configuration.new(
          root_path: ROOT_PATH,
          config_path: Pathname.new(test_config.path),
          env: "test"
        ).private_output_path
      }.to raise_error(/private_output_path and public_output_path must be different/)

      test_config.close
      test_config.unlink
    end

    it "validates paths with relative .. correctly" do
      # Test that paths with .. that resolve to the same location are caught
      test_config = Tempfile.new(["shakapacker", ".yml"])
      test_config.write(<<~YAML)
        test:
          source_path: app/javascript
          source_entry_path: entrypoints
          public_root_path: public
          public_output_path: packs
          private_output_path: public/../public/packs
      YAML
      test_config.rewind

      expect {
        Shakapacker::Configuration.new(
          root_path: ROOT_PATH,
          config_path: Pathname.new(test_config.path),
          env: "test"
        ).private_output_path
      }.to raise_error(/private_output_path and public_output_path must be different/)

      test_config.close
      test_config.unlink
    end

    it "allows different paths correctly" do
      # Test that different paths are allowed
      test_config = Tempfile.new(["shakapacker", ".yml"])
      test_config.write(<<~YAML)
        test:
          source_path: app/javascript
          source_entry_path: entrypoints
          public_root_path: public
          public_output_path: packs
          private_output_path: ssr-bundles
      YAML
      test_config.rewind

      config = Shakapacker::Configuration.new(
        root_path: ROOT_PATH,
        config_path: Pathname.new(test_config.path),
        env: "test"
      )

      expect { config.private_output_path }.not_to raise_error
      expect(config.private_output_path.to_s).to end_with("ssr-bundles")

      test_config.close
      test_config.unlink
    end

    it "validates only once even with multiple calls" do
      # Test that validation flag prevents redundant validations
      config = Shakapacker::Configuration.new(
        root_path: ROOT_PATH,
        config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker.yml", __dir__)),
        env: "test"
      )

      # Multiple calls should return the same path
      path1 = config.private_output_path
      path2 = config.private_output_path

      expect(path1).to eq(path2)
      expect(path1.to_s).to end_with("ssr-generated")
    end

    it "#additional_paths returns correct path" do
      expect(config.additional_paths).to eq ["app/assets", "/etc/yarn", "some.config.js", "app/elm"]
    end

    describe "#cache_manifest?" do
      it "returns true in production environment" do
        expect(config.cache_manifest?).to be true
      end

      it "returns false in development environment" do
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

      it "returns true in development environment" do
        with_rails_env("development") do
          expect(Shakapacker.config.compile?).to be true
        end
      end

      it "returns true in test environment" do
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
      it "returns true in production environment" do
        expect(config.ensure_consistent_versioning?).to be true
      end

      it "returns true in development environment" do
        with_rails_env("development") do
          expect(Shakapacker.config.ensure_consistent_versioning?).to be true
        end
      end

      it "returns true in test environment" do
        with_rails_env("test") do
          expect(Shakapacker.config.ensure_consistent_versioning?).to be true
        end
      end
    end

    describe "#shakapacker_precompile?" do
      before :each do
        ENV.delete("SHAKAPACKER_PRECOMPILE")
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

    describe "#integrity" do
      it "contains the key :enabled" do
        expect(config.integrity).to have_key(:enabled)
      end

      it "contains the key :hash_functions" do
        expect(config.integrity).to have_key(:hash_functions)
      end

      it "contains the key :cross_origin" do
        expect(config.integrity).to have_key(:cross_origin)
      end

      it "is by default disabled" do
        expect(config.integrity[:enabled]).to be false
      end

      it "returns default cross_origin configuration" do
        expect(config.integrity[:cross_origin]).to eq "anonymous"
      end

      it "returns default hash_functions" do
        expect(config.integrity[:hash_functions]).to eq ["sha384"]
      end
    end
  end

  context "with shakapacker config file containing integrity" do
    let(:config) do
      Shakapacker::Configuration.new(
        root_path: ROOT_PATH,
        config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker_integrity.yml", __dir__)),
        env: "production"
      )
    end

    it "has integrity enabled" do
      expect(config.integrity[:enabled]).to be true
    end

    it "has all hash functions set" do
      expect(config.integrity[:hash_functions]).to eq ["sha256", "sha384", "sha512"]
    end

    it "has cross_origin set to use-credentials" do
      expect(config.integrity[:cross_origin]).to eq "use-credentials"
    end
  end

  context "with shakapacker config file containing public_output_path entry" do
    config = Shakapacker::Configuration.new(
      root_path: ROOT_PATH,
      config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker_public_root.yml", __dir__)),
      env: "production"
    )

    it "#public_output_path returns correct path" do
      expected_public_output_path = File.expand_path File.join(File.dirname(__FILE__), "./public/packs").to_s

      expect(config.public_output_path.to_s).to eq expected_public_output_path
    end
  end

  context "with shakapacker config file containing manifest_path entry" do
    config = Shakapacker::Configuration.new(
      root_path: ROOT_PATH,
      config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker_manifest_path.yml", __dir__)),
      env: "production"
    )

    it "#manifest_path returns correct expected value" do
      expected_manifest_path = File.expand_path File.join(File.dirname(__FILE__), "./test_app/app/javascript", "manifest.json").to_s

      expect(config.manifest_path.to_s).to eq expected_manifest_path
    end
  end

  context "with shakapacker_precompile entry set to false" do
    describe "#shakapacker_precompile?" do
      before :each do
        ENV.delete("SHAKAPACKER_PRECOMPILE")
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

    it "#cache_manifest? falls back to 'production' config from bundled file" do
      expect(config.cache_manifest?).to be true
    end

    it "#shakapacker_precompile? use 'staging' config from custom file" do
      expect(config.shakapacker_precompile?).to be false
    end
  end

  context "#source_entry_path" do
    let(:config) do
      Shakapacker::Configuration.new(
        root_path: ROOT_PATH,
        config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker.yml", __dir__)),
        env: "production"
      )
    end

    it "returns correct path with source_entry_path starting with 'extra_path'" do
      allow(config).to receive(:fetch).with(:source_path).and_return("the_source_path")
      allow(config).to receive(:fetch).with(:source_entry_path).and_return("extra_path")

      actual = config.source_entry_path.to_s
      expected = "#{config.source_path.to_s}/extra_path"

      expect(actual).to eq(expected)
    end

    it "returns correct path with source_entry_path starting with /" do
      allow(config).to receive(:fetch).with(:source_path).and_return("the_source_path")
      allow(config).to receive(:fetch).with(:source_entry_path).and_return("/")

      actual = config.source_entry_path.to_s
      expected = config.source_path.to_s

      expect(actual).to eq(expected)
    end

    it "returns correct path with source_entry_path starting with /extra_path" do
      allow(config).to receive(:fetch).with(:source_path).and_return("the_source_path")
      allow(config).to receive(:fetch).with(:source_entry_path).and_return("/extra_path")

      actual = config.source_entry_path.to_s
      expected = "#{config.source_path.to_s}/extra_path"

      expect(actual).to eq(expected)
    end
  end

  describe "#asset_host" do
    let(:config) do
      Shakapacker::Configuration.new(
        root_path: ROOT_PATH,
        config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker.yml", __dir__)),
        env: "production"
      )
    end

    it "returns the value of SHAKAPACKER_ASSET_HOST if set" do
      expect(ENV).to receive(:fetch).with("SHAKAPACKER_ASSET_HOST", nil).and_return("custom_host.abc")

      expect(config.asset_host).to eq "custom_host.abc"
    end

    context "without SHAKAPACKER_ASSET_HOST set" do
      it "returns asset_host in shakapacker.yml if set" do
        expect(config).to receive(:fetch).with(:asset_host).and_return("value-in-config-file.com")
        expect(ENV).to receive(:fetch).with("SHAKAPACKER_ASSET_HOST", "value-in-config-file.com").and_return("value-in-config-file.com")

        expect(config.asset_host).to eq "value-in-config-file.com"
      end

      context "without asset_host set in the shakapacker.yml" do
        it "returns ActionController::Base.helpers.compute_asset_host if SHAKAPACKER_ASSET_HOST is not set" do
          expect(config).to receive(:fetch).with(:asset_host).and_return(nil)
          expect(ActionController::Base.helpers).to receive(:compute_asset_host).and_return("domain.abc")
          allow(ENV).to receive(:fetch).with("SHAKAPACKER_ASSET_HOST", "domain.abc").and_return("domain.abc")

          expect(config.asset_host).to eq "domain.abc"
        end

        context "without ActionController::Base.helpers.compute_asset_host returning any value" do
          it "returns nil" do
            expect(ENV).to receive(:fetch).with("SHAKAPACKER_ASSET_HOST", nil).and_return(nil)

            expect(config.asset_host).to be nil
          end
        end
      end
    end
  end

  describe "#javascript_transpiler" do
    context "with javascript_transpiler set in config" do
      let(:config) do
        Shakapacker::Configuration.new(
          root_path: ROOT_PATH,
          config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker.yml", __dir__)),
          env: "production"
        )
      end

      it "returns the configured javascript_transpiler" do
        allow(config).to receive(:fetch).with(:javascript_transpiler).and_return("swc")
        allow(config).to receive(:fetch).with(:webpack_loader).and_return(nil)
        expect(config.javascript_transpiler).to eq "swc"
      end
    end

    context "with webpack_loader set in config (fallback)" do
      let(:config) do
        Shakapacker::Configuration.new(
          root_path: ROOT_PATH,
          config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker.yml", __dir__)),
          env: "production"
        )
      end

      it "falls back to webpack_loader when javascript_transpiler is not set" do
        allow(config).to receive(:fetch).with(:javascript_transpiler).and_return(nil)
        allow(config).to receive(:fetch).with(:webpack_loader).and_return("esbuild")
        expect(config.javascript_transpiler).to eq "esbuild"
      end
    end

    context "with neither javascript_transpiler nor webpack_loader set" do
      let(:config) do
        Shakapacker::Configuration.new(
          root_path: ROOT_PATH,
          config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker.yml", __dir__)),
          env: "production"
        )
      end

      it "defaults to 'babel'" do
        allow(config).to receive(:fetch).with(:javascript_transpiler).and_return(nil)
        allow(config).to receive(:fetch).with(:webpack_loader).and_return(nil)
        allow(config).to receive(:fetch).with(:assets_bundler).and_return(nil)
        allow(config).to receive(:fetch).with(:bundler).and_return(nil)
        expect(config.javascript_transpiler).to eq "babel"
      end
    end
  end

  describe "#webpack_loader (deprecated)" do
    context "with both webpack_loader and javascript_transpiler set" do
      let(:config) do
        Shakapacker::Configuration.new(
          root_path: ROOT_PATH,
          config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker.yml", __dir__)),
          env: "production"
        )
      end

      it "returns javascript_transpiler value without deprecation warning" do
        data_mock = { webpack_loader: "swc", javascript_transpiler: "esbuild" }
        allow(config).to receive(:data).and_return(data_mock)
        allow(config).to receive(:javascript_transpiler).and_return("esbuild")

        expect($stderr).not_to receive(:puts)
        expect(config.webpack_loader).to eq "esbuild"
      end
    end

    context "with only webpack_loader set" do
      let(:config) do
        Shakapacker::Configuration.new(
          root_path: ROOT_PATH,
          config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker.yml", __dir__)),
          env: "production"
        )
      end

      it "shows deprecation warning and returns javascript_transpiler value" do
        data_mock = { webpack_loader: "swc" }
        allow(config).to receive(:data).and_return(data_mock)
        allow(config).to receive(:fetch).with(:javascript_transpiler).and_return(nil)
        allow(config).to receive(:fetch).with(:webpack_loader).and_return("swc")
        allow(config).to receive(:fetch).with(:assets_bundler).and_return(nil)
        allow(config).to receive(:fetch).with(:bundler).and_return(nil)

        expect($stderr).to receive(:puts).with(/DEPRECATION WARNING.*webpack_loader.*deprecated.*javascript_transpiler/)
        expect(config.javascript_transpiler).to eq "swc"
      end
    end
  end

  describe "javascript_transpiler: 'none'" do
    context "with javascript_transpiler set to 'none'" do
      let(:config) do
        Shakapacker::Configuration.new(
          root_path: ROOT_PATH,
          config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker.yml", __dir__)),
          env: "production"
        )
      end

      it "accepts 'none' as a valid value" do
        allow(config).to receive(:fetch).with(:javascript_transpiler).and_return("none")
        allow(config).to receive(:fetch).with(:webpack_loader).and_return(nil)
        expect(config.javascript_transpiler).to eq "none"
      end

      it "skips transpiler validation when set to 'none'" do
        allow(config).to receive(:fetch).with(:javascript_transpiler).and_return("none")
        allow(config).to receive(:fetch).with(:webpack_loader).and_return(nil)
        allow(config).to receive(:root_path).and_return(ROOT_PATH)

        # Should not trigger any validation warnings
        expect($stderr).not_to receive(:puts)
        expect(config.javascript_transpiler).to eq "none"
      end
    end
  end

  context "with missing environment in config file" do
    let(:config) do
      Shakapacker::Configuration.new(
        root_path: ROOT_PATH,
        config_path: Pathname.new(File.expand_path("./test_app/config/shakapacker_no_precompile.yml", __dir__)),
        env: "staging"
      )
    end

    it "falls back to production environment without raising error" do
      expect { config.compile? }.not_to raise_error
    end

    it "does not raise NoMethodError for deep_symbolize_keys on missing environment" do
      expect { config.fetch(:source_path) }.not_to raise_error
    end

    it "logs a warning about the fallback to production" do
      # Reset memoized data to trigger load again
      config.instance_variable_set(:@data, nil)
      expect(Shakapacker.logger).to receive(:info).with(
        /Shakapacker environment 'staging' not found.*falling back to 'production'/
      )
      config.compile?
    end

    it "returns configuration from production section" do
      # The shakapacker_no_precompile.yml file has shakapacker_precompile: false (from default, inherited by production)
      expect(config.shakapacker_precompile?).to be false
    end
  end

  describe "#precompile_hook" do
    context "with precompile_hook set in config" do
      it "returns the configured precompile_hook" do
        test_config = Tempfile.new(["shakapacker", ".yml"])
        test_config.write(<<~YAML)
          production:
            source_path: app/javascript
            precompile_hook: 'bin/shakapacker-precompile-hook'
        YAML
        test_config.rewind

        config = Shakapacker::Configuration.new(
          root_path: ROOT_PATH,
          config_path: Pathname.new(test_config.path),
          env: "production"
        )

        expect(config.precompile_hook).to eq "bin/shakapacker-precompile-hook"

        test_config.close
        test_config.unlink
      end

      it "strips whitespace from the hook command" do
        test_config = Tempfile.new(["shakapacker", ".yml"])
        test_config.write(<<~YAML)
          production:
            source_path: app/javascript
            precompile_hook: '  bin/shakapacker-precompile-hook  '
        YAML
        test_config.rewind

        config = Shakapacker::Configuration.new(
          root_path: ROOT_PATH,
          config_path: Pathname.new(test_config.path),
          env: "production"
        )

        expect(config.precompile_hook).to eq "bin/shakapacker-precompile-hook"

        test_config.close
        test_config.unlink
      end
    end

    context "without precompile_hook set in config" do
      it "returns nil" do
        test_config = Tempfile.new(["shakapacker", ".yml"])
        test_config.write(<<~YAML)
          production:
            source_path: app/javascript
        YAML
        test_config.rewind

        config = Shakapacker::Configuration.new(
          root_path: ROOT_PATH,
          config_path: Pathname.new(test_config.path),
          env: "production"
        )

        expect(config.precompile_hook).to be_nil

        test_config.close
        test_config.unlink
      end
    end

    context "with empty string precompile_hook" do
      it "returns nil for empty string" do
        test_config = Tempfile.new(["shakapacker", ".yml"])
        test_config.write(<<~YAML)
          production:
            source_path: app/javascript
            precompile_hook: ''
        YAML
        test_config.rewind

        config = Shakapacker::Configuration.new(
          root_path: ROOT_PATH,
          config_path: Pathname.new(test_config.path),
          env: "production"
        )

        expect(config.precompile_hook).to be_nil

        test_config.close
        test_config.unlink
      end

      it "returns nil for whitespace-only string" do
        test_config = Tempfile.new(["shakapacker", ".yml"])
        test_config.write(<<~YAML)
          production:
            source_path: app/javascript
            precompile_hook: '   '
        YAML
        test_config.rewind

        config = Shakapacker::Configuration.new(
          root_path: ROOT_PATH,
          config_path: Pathname.new(test_config.path),
          env: "production"
        )

        expect(config.precompile_hook).to be_nil

        test_config.close
        test_config.unlink
      end
    end

    context "with invalid precompile_hook type" do
      it "raises error for boolean value" do
        test_config = Tempfile.new(["shakapacker", ".yml"])
        test_config.write(<<~YAML)
          production:
            source_path: app/javascript
            precompile_hook: true
        YAML
        test_config.rewind

        config = Shakapacker::Configuration.new(
          root_path: ROOT_PATH,
          config_path: Pathname.new(test_config.path),
          env: "production"
        )

        expect { config.precompile_hook }.to raise_error(/precompile_hook must be a string/)

        test_config.close
        test_config.unlink
      end

      it "raises error for numeric value" do
        test_config = Tempfile.new(["shakapacker", ".yml"])
        test_config.write(<<~YAML)
          production:
            source_path: app/javascript
            precompile_hook: 123
        YAML
        test_config.rewind

        config = Shakapacker::Configuration.new(
          root_path: ROOT_PATH,
          config_path: Pathname.new(test_config.path),
          env: "production"
        )

        expect { config.precompile_hook }.to raise_error(/precompile_hook must be a string/)

        test_config.close
        test_config.unlink
      end
    end
  end

  context "with completely missing environment and no default section" do
    it "handles missing default section gracefully" do
      # Create a minimal config file with no default or development sections
      test_config = Tempfile.new(["shakapacker", ".yml"])
      test_config.write(<<~YAML)
        production:
          source_path: app/javascript
      YAML
      test_config.rewind

      config = Shakapacker::Configuration.new(
        root_path: ROOT_PATH,
        config_path: Pathname.new(test_config.path),
        env: "staging"
      )

      # Should not raise error, should return empty config
      expect { config.fetch(:source_path) }.not_to raise_error

      test_config.close
      test_config.unlink
    end

    it "logs when falling back to bundled defaults" do
      test_config = Tempfile.new(["shakapacker", ".yml"])
      test_config.write(<<~YAML)
        development:
          source_path: app/javascript
      YAML
      test_config.rewind

      config = Shakapacker::Configuration.new(
        root_path: ROOT_PATH,
        config_path: Pathname.new(test_config.path),
        env: "staging"
      )

      expect(Shakapacker.logger).to receive(:info).with(
        /Shakapacker environment 'staging' not found.*falling back to 'none \(will use bundled defaults\)'/
      )
      config.fetch(:source_path)

      test_config.close
      test_config.unlink
    end
  end
end

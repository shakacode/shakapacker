require "spec_helper"
require "shakapacker/build_config_loader"
require "tempfile"
require "tmpdir"

describe Shakapacker::BuildConfigLoader do
  let(:loader) { described_class.new(config_file_path) }
  let(:config_file_path) { File.join(test_dir, "config", "shakapacker-builds.yml") }
  let(:test_dir) { Dir.mktmpdir }

  before do
    FileUtils.mkdir_p(File.join(test_dir, "config"))
  end

  after do
    FileUtils.rm_rf(test_dir)
  end

  describe "#exists?" do
    context "when config file exists" do
      before do
        File.write(config_file_path, "builds: {}")
      end

      it "returns true" do
        expect(loader.exists?).to be true
      end
    end

    context "when config file does not exist" do
      it "returns false" do
        expect(loader.exists?).to be false
      end
    end
  end

  describe "#load_build" do
    context "when config file does not exist" do
      it "raises an error with helpful message" do
        expect { loader.load_build("test") }.to raise_error(
          ArgumentError,
          /Config file not found.*bin\/shakapacker --init/m
        )
      end
    end

    context "when config file is invalid" do
      before do
        File.write(config_file_path, "invalid: yaml: [")
      end

      it "raises an error" do
        expect { loader.load_build("test") }.to raise_error(ArgumentError)
      end
    end

    context "when builds key is missing" do
      before do
        File.write(config_file_path, "default_bundler: webpack")
      end

      it "raises an error" do
        expect { loader.load_build("test") }.to raise_error(
          ArgumentError,
          /Config file must contain a 'builds' object/
        )
      end
    end

    context "when build name not found" do
      before do
        File.write(config_file_path, <<~YAML)
          builds:
            prod:
              description: Production build
        YAML
      end

      it "raises an error with available builds" do
        expect { loader.load_build("dev") }.to raise_error(
          ArgumentError,
          /Build 'dev' not found.*Available builds: prod/m
        )
      end
    end

    context "when build exists" do
      before do
        File.write(config_file_path, <<~YAML)
          builds:
            dev:
              description: Development build
              bundler: webpack
              environment:
                NODE_ENV: development
        YAML
      end

      it "returns the build configuration" do
        build = loader.load_build("dev")
        expect(build).to be_a(Hash)
        expect(build["description"]).to eq("Development build")
        expect(build["bundler"]).to eq("webpack")
        expect(build["environment"]).to eq("NODE_ENV" => "development")
      end
    end
  end

  describe "#resolve_build_config" do
    context "with minimal build config" do
      before do
        File.write(config_file_path, <<~YAML)
          builds:
            test:
              outputs:
                - client
        YAML
      end

      it "resolves with defaults" do
        config = loader.resolve_build_config("test")
        expect(config[:name]).to eq("test")
        expect(config[:bundler]).to eq("webpack")
        expect(config[:environment]).to eq({})
        expect(config[:outputs]).to eq(["client"])
      end
    end

    context "with full build config" do
      before do
        File.write(config_file_path, <<~YAML)
          default_bundler: rspack
          builds:
            prod:
              description: Production build
              bundler: webpack
              environment:
                NODE_ENV: production
                RAILS_ENV: production
              bundler_env:
                analyze: true
              outputs:
                - client
                - server
              config: config/webpack/custom.config.js
        YAML
      end

      it "resolves all settings correctly" do
        config = loader.resolve_build_config("prod")
        expect(config[:name]).to eq("prod")
        expect(config[:description]).to eq("Production build")
        expect(config[:bundler]).to eq("webpack")
        expect(config[:environment]).to eq(
          "NODE_ENV" => "production",
          "RAILS_ENV" => "production"
        )
        expect(config[:bundler_env]).to eq("analyze" => true)
        expect(config[:outputs]).to eq(["client", "server"])
        expect(config[:config_file]).to eq("config/webpack/custom.config.js")
      end
    end

    context "with bundler variable substitution" do
      before do
        File.write(config_file_path, <<~YAML)
          builds:
            test:
              bundler: rspack
              config: config/\${BUNDLER}/custom.config.js
              outputs:
                - client
        YAML
      end

      it "expands BUNDLER variable" do
        config = loader.resolve_build_config("test")
        expect(config[:config_file]).to eq("config/rspack/custom.config.js")
      end
    end

    context "with default bundler" do
      before do
        File.write(config_file_path, <<~YAML)
          default_bundler: rspack
          builds:
            test:
              outputs:
                - client
        YAML
      end

      it "uses default bundler from config" do
        config = loader.resolve_build_config("test")
        expect(config[:bundler]).to eq("rspack")
      end
    end

    context "with empty outputs array" do
      before do
        File.write(config_file_path, <<~YAML)
          builds:
            test:
              outputs: []
        YAML
      end

      it "raises an error" do
        expect { loader.resolve_build_config("test") }.to raise_error(
          ArgumentError,
          /Build 'test' has empty outputs array/
        )
      end
    end
  end

  describe "#uses_dev_server?" do
    context "when dev_server flag is explicitly true" do
      let(:build_config) do
        {
          dev_server: true,
          environment: { "NODE_ENV" => "development" }
        }
      end

      it "returns true" do
        expect(loader.uses_dev_server?(build_config)).to be true
      end
    end

    context "when dev_server flag is explicitly false" do
      let(:build_config) do
        {
          dev_server: false,
          environment: { "WEBPACK_SERVE" => "true" }
        }
      end

      it "returns false (explicit flag takes precedence)" do
        expect(loader.uses_dev_server?(build_config)).to be false
      end
    end

    context "when dev_server flag is not set (fallback to environment)" do
      context "when WEBPACK_SERVE is true" do
        let(:build_config) do
          {
            environment: { "WEBPACK_SERVE" => "true" }
          }
        end

        it "returns true" do
          expect(loader.uses_dev_server?(build_config)).to be true
        end
      end

      context "when HMR is true" do
        let(:build_config) do
          {
            environment: { "HMR" => "true" }
          }
        end

        it "returns true" do
          expect(loader.uses_dev_server?(build_config)).to be true
        end
      end

      context "when neither WEBPACK_SERVE nor HMR is set" do
        let(:build_config) do
          {
            environment: { "NODE_ENV" => "production" }
          }
        end

        it "returns false" do
          expect(loader.uses_dev_server?(build_config)).to be false
        end
      end

      context "when WEBPACK_SERVE is false" do
        let(:build_config) do
          {
            environment: { "WEBPACK_SERVE" => "false" }
          }
        end

        it "returns false" do
          expect(loader.uses_dev_server?(build_config)).to be false
        end
      end
    end
  end
end

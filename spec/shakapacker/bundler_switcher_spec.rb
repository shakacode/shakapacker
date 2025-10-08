require_relative "../spec_helper"
require "shakapacker/bundler_switcher"
require "fileutils"
require "tmpdir"
require "yaml"

describe Shakapacker::BundlerSwitcher do
  let(:root_path) { Pathname.new(Dir.mktmpdir) }
  let(:config_path) { root_path.join("config/shakapacker.yml") }
  let(:custom_config_path) { root_path.join(".shakapacker-switch-bundler-dependencies.yml") }
  let(:switcher) { described_class.new(root_path) }

  # Helper to load YAML with Ruby version compatibility
  def load_yaml_for_test(path)
    if YAML.respond_to?(:unsafe_load)
      YAML.unsafe_load(File.read(path))
    else
      begin
        YAML.safe_load(File.read(path), permitted_classes: [], permitted_symbols: [], aliases: true)
      rescue ArgumentError
        YAML.load(File.read(path)) # rubocop:disable Security/YAMLLoad
      end
    end
  end

  before do
    FileUtils.mkdir_p(root_path.join("config"))

    # Create a sample shakapacker.yml
    config_content = <<~YAML
      default: &default
        source_path: app/javascript
        assets_bundler: webpack
        javascript_transpiler: babel

      development:
        <<: *default

      production:
        <<: *default
    YAML
    File.write(config_path, config_content)
  end

  after do
    FileUtils.rm_rf(root_path)
  end

  describe "#initialize" do
    it "uses provided root_path" do
      expect(switcher.root_path).to eq(root_path)
    end

    context "when no root_path provided" do
      it "uses Rails.root if Rails is defined" do
        stub_const("Rails", double(root: root_path))
        expect(described_class.new.root_path).to eq(root_path)
      end

      it "uses current directory if Rails is not defined" do
        hide_const("Rails")
        expect(described_class.new.root_path).to eq(Pathname.new(Dir.pwd))
      end
    end
  end

  describe "#current_bundler" do
    it "returns the current bundler from config" do
      expect(switcher.current_bundler).to eq("webpack")
    end

    it "returns 'webpack' as default when not specified" do
      config_without_bundler = <<~YAML
        default: &default
          source_path: app/javascript

        development:
          <<: *default
      YAML
      File.write(config_path, config_without_bundler)
      expect(switcher.current_bundler).to eq("webpack")
    end
  end

  describe "#switch_to" do
    it "raises ArgumentError for invalid bundler" do
      expect do
        switcher.switch_to("invalid")
      end.to raise_error(ArgumentError, /Invalid bundler/)
    end

    it "accepts 'webpack' as valid bundler" do
      expect { switcher.switch_to("webpack") }.not_to raise_error
    end

    it "accepts 'rspack' as valid bundler" do
      expect { switcher.switch_to("rspack") }.not_to raise_error
    end

    it "updates config file when switching from webpack to rspack" do
      switcher.switch_to("rspack")
      config = load_yaml_for_test(config_path)
      expect(config["default"]["assets_bundler"]).to eq("rspack")
    end

    it "updates config file when switching from rspack to webpack" do
      # First set to rspack
      config_content = File.read(config_path)
      config_content.gsub!("webpack", "rspack")
      File.write(config_path, config_content)

      switcher.switch_to("webpack")
      config = load_yaml_for_test(config_path)
      expect(config["default"]["assets_bundler"]).to eq("webpack")
    end

    it "updates javascript_transpiler to swc when switching to rspack" do
      switcher.switch_to("rspack")
      config = load_yaml_for_test(config_path)
      expect(config["default"]["javascript_transpiler"]).to eq("swc")
    end

    it "does not update javascript_transpiler if already swc" do
      config_content = File.read(config_path)
      config_content.gsub!("babel", "swc")
      File.write(config_path, config_content)

      switcher.switch_to("rspack")
      config = load_yaml_for_test(config_path)
      expect(config["default"]["javascript_transpiler"]).to eq("swc")
    end

    it "preserves config file structure and comments" do
      config_with_comments = <<~YAML
        # This is a comment
        default: &default
          source_path: app/javascript
          assets_bundler: webpack  # inline comment
          javascript_transpiler: babel

        development:
          <<: *default
      YAML
      File.write(config_path, config_with_comments)

      switcher.switch_to("rspack")
      updated_content = File.read(config_path)
      expect(updated_content).to include("# This is a comment")
      expect(updated_content).to include("# inline comment")
    end

    context "when already using the target bundler" do
      it "does not reinstall deps when install_deps is false" do
        expect(switcher).not_to receive(:system)
        switcher.switch_to("webpack")
      end

      it "reinstalls deps when install_deps is true" do
        allow(switcher).to receive(:system).and_return(true)
        expect(switcher).to receive(:system).at_least(:once)
        switcher.switch_to("webpack", install_deps: true)
      end
    end

    context "with install_deps option" do
      it "calls npm to install dependencies when install_deps is true" do
        allow(switcher).to receive(:system).and_return(true)

        # Expect uninstall calls for webpack deps (including SWC)
        expect(switcher).to receive(:system).with("npm", "uninstall", "webpack", "webpack-cli", "webpack-dev-server", "@pmmmwh/react-refresh-webpack-plugin", "@swc/core", "swc-loader").and_return(true)
        expect(switcher).to receive(:system).with("npm", "uninstall", "webpack-assets-manifest", "webpack-merge").and_return(true)

        # Expect install calls for rspack deps
        expect(switcher).to receive(:system).with("npm", "install", "--save-dev", "@rspack/cli", "@rspack/plugin-react-refresh").and_return(true)
        expect(switcher).to receive(:system).with("npm", "install", "--save", "@rspack/core", "rspack-manifest-plugin").and_return(true)

        switcher.switch_to("rspack", install_deps: true)
      end

      it "does not call npm when install_deps is false" do
        expect(switcher).not_to receive(:system)
        switcher.switch_to("rspack", install_deps: false)
      end
    end
  end

  describe "#init_config" do
    it "creates custom config file" do
      switcher.init_config
      expect(File.exist?(custom_config_path)).to be true
    end

    it "creates valid YAML config" do
      switcher.init_config
      config = load_yaml_for_test(custom_config_path)
      expect(config).to have_key("rspack")
      expect(config).to have_key("webpack")
    end

    it "includes default rspack dependencies" do
      switcher.init_config
      config = load_yaml_for_test(custom_config_path)
      expect(config["rspack"]["devDependencies"]).to include("@rspack/cli")
      expect(config["rspack"]["dependencies"]).to include("@rspack/core")
    end

    it "includes default webpack dependencies" do
      switcher.init_config
      config = load_yaml_for_test(custom_config_path)
      expect(config["webpack"]["devDependencies"]).to include("webpack")
      expect(config["webpack"]["devDependencies"]).to include("webpack-cli")
    end

    it "does not overwrite existing config file" do
      File.write(custom_config_path, "existing: content")
      switcher.init_config
      expect(File.read(custom_config_path)).to eq("existing: content")
    end
  end

  describe "#show_usage" do
    it "displays current bundler" do
      expect { switcher.show_usage }.to output(/Current bundler: webpack/).to_stdout
    end

    it "displays usage information" do
      expect { switcher.show_usage }.to output(/Usage:/).to_stdout
    end

    it "displays examples" do
      expect { switcher.show_usage }.to output(/Examples:/).to_stdout
    end
  end

  describe "custom dependencies" do
    let(:custom_deps) do
      {
        "rspack" => {
          "devDependencies" => ["@rspack/cli", "custom-rspack-dep"],
          "dependencies" => ["@rspack/core"]
        },
        "webpack" => {
          "devDependencies" => ["webpack", "custom-webpack-dep"],
          "dependencies" => ["webpack-merge"]
        }
      }
    end

    before do
      File.write(custom_config_path, YAML.dump(custom_deps))
    end

    it "uses custom dependencies when config file exists" do
      allow(switcher).to receive(:system).and_return(true)
      expect(switcher).to receive(:system).with("npm", "install", "--save-dev", "@rspack/cli", "custom-rspack-dep").and_return(true)
      switcher.switch_to("rspack", install_deps: true)
    end
  end

  describe "error handling" do
    it "raises error when npm install fails" do
      allow(switcher).to receive(:system).and_return(false)
      expect do
        switcher.switch_to("rspack", install_deps: true)
      end.to raise_error(/Failed to install/)
    end

    it "raises error when custom config YAML is invalid" do
      File.write(custom_config_path, "invalid: yaml: content: :")
      allow(switcher).to receive(:system).and_return(true)
      expect do
        switcher.switch_to("rspack", install_deps: true)
      end.to raise_error(Psych::SyntaxError)
    end
  end
end

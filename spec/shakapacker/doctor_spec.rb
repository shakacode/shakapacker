require_relative "../spec_helper"
require "shakapacker"
require "shakapacker/doctor"
require "fileutils"
require "tmpdir"

describe Shakapacker::Doctor do
  let(:root_path) { Pathname.new(Dir.mktmpdir) }
  let(:config_path) { root_path.join("config/shakapacker.yml") }
  let(:package_json_path) { root_path.join("package.json") }
  let(:source_path) { root_path.join("app/javascript") }

  let(:config) do
    double("config",
           config_path: config_path,
           source_path: source_path,
           javascript_transpiler: "babel",
           assets_bundler: "webpack")
  end

  let(:doctor) { described_class.new(config, root_path) }

  before do
    stub_const("Rails", double(root: root_path)) if !defined?(Rails)
    FileUtils.mkdir_p(root_path.join("config"))
    FileUtils.mkdir_p(source_path)
  end

  after do
    FileUtils.rm_rf(root_path)
  end

  describe "#initialize" do
    it "initializes with empty issues and warnings" do
      expect(doctor.issues).to be_empty
      expect(doctor.warnings).to be_empty
    end

    it "uses provided config and root_path" do
      expect(doctor.config).to eq(config)
      expect(doctor.root_path).to eq(root_path)
    end

    context "when no arguments provided" do
      it "uses default Shakapacker config" do
        stub_const("Rails", double(root: root_path))
        # Mock Shakapacker module with config method
        allow(Shakapacker).to receive_message_chain(:config).and_return(config)
        doctor_default = described_class.new
        expect(doctor_default.config).to eq(config)
      end
    end
  end

  describe "#success?" do
    it "returns true when no issues" do
      expect(doctor.success?).to be true
    end

    it "returns false when issues exist" do
      doctor.instance_variable_set(:@issues, ["test issue"])
      expect(doctor.success?).to be false
    end

    it "returns true when only warnings exist" do
      doctor.instance_variable_set(:@warnings, ["test warning"])
      expect(doctor.success?).to be true
    end
  end

  describe "#run" do
    before do
      # Create config file
      File.write(config_path, "test: config")

      # Create package.json with dependencies
      package_json = {
        "dependencies" => {
          "webpack" => "^5.0.0",
          "webpack-cli" => "^4.0.0",
          "babel-loader" => "^9.0.0",
          "css-loader" => "^6.0.0",
          "style-loader" => "^3.0.0"
        }
      }
      File.write(package_json_path, JSON.generate(package_json))

      # Mock node version check
      allow(doctor).to receive(:`).with("node --version").and_return("v20.0.0\n")

      # Prevent exit
      allow(doctor).to receive(:exit)

      # Suppress output
      allow(doctor).to receive(:puts)
    end

    it "performs all checks" do
      expect(doctor).to receive(:perform_checks)
      expect(doctor).to receive(:report_results)
      doctor.run
    end
  end

  describe "configuration checks" do
    context "when config file exists" do
      before do
        File.write(config_path, "test: config")
      end

      it "does not add issues" do
        doctor.send(:check_config_file)
        expect(doctor.issues).to be_empty
      end
    end

    context "when config file does not exist" do
      before do
        FileUtils.rm_rf(config_path.dirname)
      end

      it "adds config file missing issue" do
        doctor.send(:check_config_file)
        expect(doctor.issues).to include(match(/Configuration file not found/))
      end
    end
  end

  describe "Node.js checks" do
    context "when Node.js is installed" do
      before do
        allow(doctor).to receive(:`).with("node --version").and_return("v20.0.0\n")
      end

      it "does not add issues" do
        doctor.send(:check_node_installation)
        expect(doctor.issues).to be_empty
      end
    end

    context "when Node.js is not installed" do
      before do
        allow(doctor).to receive(:`).with("node --version").and_raise(Errno::ENOENT)
      end

      it "adds node missing issue" do
        doctor.send(:check_node_installation)
        expect(doctor.issues).to include(match(/Node.js is not installed/))
      end
    end
  end

  describe "package manager checks" do
    context "when yarn.lock exists" do
      before do
        File.write(root_path.join("yarn.lock"), "")
      end

      it "detects yarn" do
        expect(doctor.send(:detect_package_manager)).to eq("yarn")
      end
    end

    context "when pnpm-lock.yaml exists" do
      before do
        File.write(root_path.join("pnpm-lock.yaml"), "")
      end

      it "detects pnpm" do
        expect(doctor.send(:detect_package_manager)).to eq("pnpm")
      end
    end

    context "when package-lock.json exists" do
      before do
        File.write(root_path.join("package-lock.json"), "")
      end

      it "detects npm" do
        expect(doctor.send(:detect_package_manager)).to eq("npm")
      end
    end

    context "when no lock file exists" do
      it "returns nil and adds issue" do
        expect(doctor.send(:detect_package_manager)).to be_nil
        doctor.send(:check_package_manager)
        expect(doctor.issues).to include(match(/No package manager lock file found/))
      end
    end
  end

  describe "binstub checks" do
    let(:binstub_path) { root_path.join("bin/shakapacker") }

    context "when binstub exists" do
      before do
        FileUtils.mkdir_p(binstub_path.dirname)
        File.write(binstub_path, "#!/usr/bin/env ruby")
      end

      it "does not add warnings" do
        doctor.send(:check_binstub)
        expect(doctor.warnings).to be_empty
      end
    end

    context "when binstub does not exist" do
      it "adds binstub warning" do
        doctor.send(:check_binstub)
        expect(doctor.warnings).to include(match(/Shakapacker binstub not found/))
      end
    end
  end

  describe "JavaScript transpiler checks" do
    before do
      File.write(config_path, "test: config")
    end

    context "when babel-loader is installed" do
      before do
        package_json = {
          "devDependencies" => {
            "babel-loader" => "^9.0.0"
          }
        }
        File.write(package_json_path, JSON.generate(package_json))
      end

      it "does not add issues" do
        doctor.send(:check_javascript_transpiler_dependencies)
        expect(doctor.issues).to be_empty
      end
    end

    context "when babel-loader is missing" do
      before do
        File.write(package_json_path, JSON.generate({}))
      end

      it "adds missing dependency issue" do
        doctor.send(:check_javascript_transpiler_dependencies)
        expect(doctor.issues).to include(match(/Missing required dependency 'babel-loader'/))
      end
    end

    context "when transpiler is none" do
      before do
        allow(config).to receive(:javascript_transpiler).and_return("none")
      end

      it "skips check" do
        doctor.send(:check_javascript_transpiler_dependencies)
        expect(doctor.issues).to be_empty
      end
    end
  end

  describe "CSS dependency checks" do
    context "when CSS loaders are installed" do
      before do
        package_json = {
          "devDependencies" => {
            "css-loader" => "^6.0.0",
            "style-loader" => "^3.0.0",
            "mini-css-extract-plugin" => "^2.0.0"
          }
        }
        File.write(package_json_path, JSON.generate(package_json))
      end

      it "does not add issues" do
        doctor.send(:check_css_dependencies)
        expect(doctor.issues).to be_empty
        expect(doctor.warnings).to be_empty
      end
    end

    context "when CSS loaders are missing" do
      before do
        File.write(package_json_path, JSON.generate({}))
      end

      it "adds missing dependency issues" do
        doctor.send(:check_css_dependencies)
        expect(doctor.issues).to include(match(/Missing required dependency 'css-loader'/))
        expect(doctor.issues).to include(match(/Missing required dependency 'style-loader'/))
        expect(doctor.warnings).to include(match(/Optional dependency 'mini-css-extract-plugin'/))
      end
    end
  end

  describe "bundler dependency checks" do
    before do
      File.write(config_path, "test: config")
    end

    context "when using webpack" do
      context "with webpack dependencies installed" do
        before do
          package_json = {
            "devDependencies" => {
              "webpack" => "^5.0.0",
              "webpack-cli" => "^4.0.0"
            }
          }
          File.write(package_json_path, JSON.generate(package_json))
        end

        it "does not add issues" do
          doctor.send(:check_bundler_dependencies)
          expect(doctor.issues).to be_empty
        end
      end

      context "with webpack dependencies missing" do
        before do
          File.write(package_json_path, JSON.generate({}))
        end

        it "adds missing dependency issues" do
          doctor.send(:check_bundler_dependencies)
          expect(doctor.issues).to include(match(/Missing required dependency 'webpack'/))
          expect(doctor.issues).to include(match(/Missing required dependency 'webpack-cli'/))
        end
      end
    end

    context "when using rspack" do
      before do
        allow(config).to receive(:assets_bundler).and_return("rspack")
      end

      context "with rspack dependencies installed" do
        before do
          package_json = {
            "devDependencies" => {
              "@rspack/core" => "^1.0.0",
              "@rspack/cli" => "^1.0.0"
            }
          }
          File.write(package_json_path, JSON.generate(package_json))
        end

        it "does not add issues" do
          doctor.send(:check_bundler_dependencies)
          expect(doctor.issues).to be_empty
        end
      end

      context "with rspack dependencies missing" do
        before do
          File.write(package_json_path, JSON.generate({}))
        end

        it "adds missing dependency issues" do
          doctor.send(:check_bundler_dependencies)
          expect(doctor.issues).to include(match(/Missing required dependency '@rspack\/core'/))
          expect(doctor.issues).to include(match(/Missing required dependency '@rspack\/cli'/))
        end
      end
    end
  end

  describe "file type dependency checks" do
    before do
      File.write(config_path, "test: config")
      File.write(package_json_path, JSON.generate({}))
    end

    context "with TypeScript files" do
      before do
        FileUtils.mkdir_p(source_path)
        File.write(source_path.join("app.tsx"), "")
      end

      it "checks for TypeScript dependencies" do
        doctor.send(:check_file_type_dependencies)
        expect(doctor.warnings).to include(match(/@babel\/preset-typescript/))
      end
    end

    context "with Sass files" do
      before do
        FileUtils.mkdir_p(source_path)
        File.write(source_path.join("styles.scss"), "")
      end

      it "checks for Sass dependencies" do
        doctor.send(:check_file_type_dependencies)
        expect(doctor.issues).to include(match(/sass-loader/))
        expect(doctor.issues).to include(match(/sass/))
      end
    end

    context "with PostCSS config" do
      before do
        File.write(root_path.join("postcss.config.js"), "")
      end

      it "checks for PostCSS dependencies" do
        doctor.send(:check_file_type_dependencies)
        expect(doctor.issues).to include(match(/postcss/))
        expect(doctor.issues).to include(match(/postcss-loader/))
      end
    end
  end

  describe "package_installed?" do
    context "with package in dependencies" do
      before do
        package_json = {
          "dependencies" => {
            "webpack" => "^5.0.0"
          }
        }
        File.write(package_json_path, JSON.generate(package_json))
      end

      it "returns true" do
        expect(doctor.send(:package_installed?, "webpack")).to be true
      end
    end

    context "with package in devDependencies" do
      before do
        package_json = {
          "devDependencies" => {
            "webpack" => "^5.0.0"
          }
        }
        File.write(package_json_path, JSON.generate(package_json))
      end

      it "returns true" do
        expect(doctor.send(:package_installed?, "webpack")).to be true
      end
    end

    context "with package not installed" do
      before do
        File.write(package_json_path, JSON.generate({}))
      end

      it "returns false" do
        expect(doctor.send(:package_installed?, "webpack")).to be false
      end
    end

    context "with invalid JSON" do
      before do
        File.write(package_json_path, "invalid json")
      end

      it "returns false" do
        expect(doctor.send(:package_installed?, "webpack")).to be false
      end
    end

    context "without package.json" do
      it "returns false" do
        expect(doctor.send(:package_installed?, "webpack")).to be false
      end
    end
  end
end

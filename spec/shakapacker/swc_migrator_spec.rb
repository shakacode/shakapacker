require "spec_helper"
require "shakapacker/swc_migrator"
require "tmpdir"
require "pathname"
require "logger"

describe Shakapacker::SwcMigrator do
  let(:root_path) { Pathname.new(Dir.mktmpdir) }
  let(:logger) { instance_double(Logger, info: nil, error: nil) }
  let(:migrator) { described_class.new(root_path, logger: logger) }

  after do
    FileUtils.rm_rf(root_path)
  end

  describe "#migrate_to_swc" do
    context "with valid configuration" do
      before do
        # Create config directory
        FileUtils.mkdir_p(root_path.join("config"))

        # Create shakapacker.yml with babel config
        File.write(root_path.join("config/shakapacker.yml"), <<~YAML)
          default: &default
            source_path: app/packs
            babel: true

          development:
            <<: *default
            compile: true
            babel:
              preset_env: true

          production:
            <<: *default
            compile: false
            babel:
              preset_env: false
        YAML

        # Create package.json with babel packages
        File.write(root_path.join("package.json"), JSON.pretty_generate({
          "name": "test-app",
          "dependencies": {
            "@babel/runtime": "^7.20.0"
          },
          "devDependencies": {
            "@babel/core": "^7.20.0",
            "babel-loader": "^9.1.0"
          }
        }))
      end

      it "updates shakapacker.yml to use swc" do
        migrator.migrate_to_swc(run_installer: false)

        config = begin
          YAML.load_file(root_path.join("config/shakapacker.yml"), aliases: true)
        rescue ArgumentError
          YAML.load_file(root_path.join("config/shakapacker.yml"))
        end
        expect(config["default"]["swc"]).to eq(true)
        expect(config["default"]["babel"]).to be_nil
        expect(config["development"]["babel"]).to be_nil
        expect(config["development"]["swc"]).to eq(true)
        expect(config["production"]["babel"]).to be_nil
        expect(config["production"]["swc"]).to eq(true)
      end

      it "installs SWC packages" do
        migrator.migrate_to_swc(run_installer: false)

        package_json = JSON.parse(File.read(root_path.join("package.json")))
        expect(package_json["devDependencies"]["@swc/core"]).to eq("^1.7.39")
        expect(package_json["devDependencies"]["swc-loader"]).to eq("^0.2.6")
      end

      it "creates .swcrc file" do
        migrator.migrate_to_swc(run_installer: false)

        expect(root_path.join(".swcrc")).to exist
        swcrc = JSON.parse(File.read(root_path.join(".swcrc")))
        expect(swcrc["jsc"]["parser"]["jsx"]).to eq(true)
        expect(swcrc["jsc"]["transform"]["react"]["runtime"]).to eq("automatic")
        expect(swcrc["module"]["type"]).to eq("es6")
      end

      it "returns results hash" do
        results = migrator.migrate_to_swc(run_installer: false)

        expect(results[:config_updated]).to eq(true)
        expect(results[:packages_installed]).to include("@swc/core" => "^1.7.39")
        expect(results[:swcrc_created]).to eq(true)
        expect(results[:babel_packages_found]).to include("@babel/runtime", "@babel/core", "babel-loader")
      end

      it "logs cleanup recommendations when babel packages found" do
        migrator.migrate_to_swc(run_installer: false)

        expect(logger).to have_received(:info).with(/Cleanup Recommendations/)
        expect(logger).to have_received(:info).with(/Found the following Babel packages/)
        expect(logger).to have_received(:info).with(/rails shakapacker:clean_babel_packages/)
      end

      it "runs package manager install when packages are added" do
        allow(migrator).to receive(:system).and_return(true)

        migrator.migrate_to_swc(run_installer: true)

        expect(migrator).to have_received(:system).with("npm install")
      end
    end

    context "when .swcrc already exists" do
      before do
        FileUtils.mkdir_p(root_path.join("config"))
        File.write(root_path.join(".swcrc"), "{}")
        File.write(root_path.join("package.json"), "{}")
        File.write(root_path.join("config/shakapacker.yml"), "default: {}")
      end

      it "does not overwrite existing .swcrc" do
        existing_content = File.read(root_path.join(".swcrc"))
        migrator.migrate_to_swc(run_installer: false)
        expect(File.read(root_path.join(".swcrc"))).to eq(existing_content)
      end

      it "returns swcrc_created as false" do
        results = migrator.migrate_to_swc(run_installer: false)
        expect(results[:swcrc_created]).to eq(false)
      end
    end

    context "when SWC packages already installed" do
      before do
        FileUtils.mkdir_p(root_path.join("config"))
        File.write(root_path.join("config/shakapacker.yml"), "default: {}")
        File.write(root_path.join("package.json"), JSON.pretty_generate({
          "devDependencies": {
            "@swc/core": "^1.5.0",
            "swc-loader": "^0.2.0"
          }
        }))
      end

      it "does not reinstall packages" do
        migrator.migrate_to_swc(run_installer: false)
        package_json = JSON.parse(File.read(root_path.join("package.json")))
        expect(package_json["devDependencies"]["@swc/core"]).to eq("^1.5.0")
        expect(package_json["devDependencies"]["swc-loader"]).to eq("^0.2.0")
      end

      it "returns empty packages_installed" do
        results = migrator.migrate_to_swc(run_installer: false)
        expect(results[:packages_installed]).to eq({})
      end
    end

    context "with missing files" do
      it "handles missing shakapacker.yml" do
        File.write(root_path.join("package.json"), "{}")
        results = migrator.migrate_to_swc(run_installer: false)
        expect(results[:config_updated]).to eq(false)
      end

      it "handles missing package.json" do
        FileUtils.mkdir_p(root_path.join("config"))
        File.write(root_path.join("config/shakapacker.yml"), "default: {}")
        results = migrator.migrate_to_swc(run_installer: false)
        expect(results[:packages_installed]).to eq({})
      end
    end

    context "with malformed files" do
      it "handles malformed YAML" do
        FileUtils.mkdir_p(root_path.join("config"))
        File.write(root_path.join("config/shakapacker.yml"), "invalid: yaml: content:")
        File.write(root_path.join("package.json"), "{}")

        expect { migrator.migrate_to_swc(run_installer: false) }.not_to raise_error
        expect(logger).to have_received(:error).with(/Failed to update config/)
      end

      it "handles malformed JSON" do
        FileUtils.mkdir_p(root_path.join("config"))
        File.write(root_path.join("config/shakapacker.yml"), "default: {}")
        File.write(root_path.join("package.json"), "invalid json")

        expect { migrator.migrate_to_swc(run_installer: false) }.not_to raise_error
        expect(logger).to have_received(:error).with(/Failed to install packages/)
      end
    end
  end

  describe "#clean_babel_packages" do
    context "with ESLint using Babel parser in .eslintrc" do
      before do
        File.write(root_path.join("package.json"), JSON.pretty_generate({
          "name": "test-app",
          "devDependencies": {
            "@babel/core": "^7.20.0",
            "@babel/eslint-parser": "^7.20.0",
            "babel-loader": "^9.1.0"
          }
        }))
        File.write(root_path.join(".eslintrc.js"), 'module.exports = { parser: "@babel/eslint-parser" }')
      end

      it "warns about ESLint using Babel" do
        migrator.clean_babel_packages(run_installer: false)

        expect(logger).to have_received(:info).with(/WARNING: ESLint configuration detected/)
        expect(logger).to have_received(:info).with(/switch to @typescript-eslint\/parser/)
      end
    end

    context "with ESLint using Babel parser in package.json" do
      before do
        File.write(root_path.join("package.json"), JSON.pretty_generate({
          "name": "test-app",
          "devDependencies": {
            "@babel/core": "^7.20.0",
            "babel-loader": "^9.1.0"
          },
          "eslintConfig": {
            "parser": "@babel/eslint-parser",
            "extends": ["eslint:recommended"]
          }
        }))
      end

      it "warns about ESLint using Babel in package.json" do
        migrator.clean_babel_packages(run_installer: false)

        expect(logger).to have_received(:info).with(/WARNING: ESLint configuration detected/)
        expect(logger).to have_received(:info).with(/switch to @typescript-eslint\/parser/)
      end
    end

    context "with babel packages installed" do
      before do
        File.write(root_path.join("package.json"), JSON.pretty_generate({
          "name": "test-app",
          "dependencies": {
            "@babel/runtime": "^7.20.0",
            "other-package": "^1.0.0"
          },
          "devDependencies": {
            "@babel/core": "^7.20.0",
            "@babel/preset-env": "^7.20.0",
            "@babel/preset-react": "^7.20.0",
            "babel-loader": "^9.1.0",
            "webpack": "^5.0.0"
          }
        }))

        # Create babel config files
        File.write(root_path.join(".babelrc"), "{}")
        File.write(root_path.join("babel.config.js"), "module.exports = {}")
      end

      it "removes babel packages from dependencies" do
        result = migrator.clean_babel_packages(run_installer: false)

        package_json = JSON.parse(File.read(root_path.join("package.json")))
        expect(package_json["dependencies"]["@babel/runtime"]).to be_nil
        expect(package_json["dependencies"]["other-package"]).to eq("^1.0.0")
      end

      it "removes babel packages from devDependencies" do
        result = migrator.clean_babel_packages(run_installer: false)

        package_json = JSON.parse(File.read(root_path.join("package.json")))
        expect(package_json["devDependencies"]["@babel/core"]).to be_nil
        expect(package_json["devDependencies"]["babel-loader"]).to be_nil
        expect(package_json["devDependencies"]["webpack"]).to eq("^5.0.0")
      end

      it "deletes babel config files" do
        result = migrator.clean_babel_packages(run_installer: false)

        expect(root_path.join(".babelrc")).not_to exist
        expect(root_path.join("babel.config.js")).not_to exist
      end

      it "returns removed packages and deleted files" do
        result = migrator.clean_babel_packages(run_installer: false)

        expect(result[:removed_packages]).to include(
          "@babel/runtime",
          "@babel/core",
          "@babel/preset-env",
          "@babel/preset-react",
          "babel-loader"
        )
        expect(result[:config_files_deleted]).to include(".babelrc", "babel.config.js")
      end
    end

    context "with no babel packages" do
      before do
        File.write(root_path.join("package.json"), JSON.pretty_generate({
          "name": "test-app",
          "devDependencies": {
            "@swc/core": "^1.7.0",
            "webpack": "^5.0.0"
          }
        }))
      end

      it "returns empty arrays" do
        result = migrator.clean_babel_packages(run_installer: false)
        expect(result[:removed_packages]).to eq([])
        expect(result[:config_files_deleted]).to eq([])
      end

      it "does not modify package.json" do
        original_content = File.read(root_path.join("package.json"))
        migrator.clean_babel_packages(run_installer: false)
        expect(File.read(root_path.join("package.json"))).to eq(original_content)
      end
    end

    context "without package.json" do
      it "returns empty result and logs error" do
        result = migrator.clean_babel_packages(run_installer: false)
        expect(result[:removed_packages]).to eq([])
        expect(result[:config_files_deleted]).to eq([])
        expect(logger).to have_received(:error).with("❌ No package.json found")
      end
    end

    context "with various babel config files" do
      before do
        File.write(root_path.join("package.json"), JSON.pretty_generate({
          "devDependencies": { "@babel/core": "^7.0.0" }
        }))
        File.write(root_path.join(".babelrc"), "{}")
        File.write(root_path.join(".babelrc.js"), "module.exports = {}")
        File.write(root_path.join("babel.config.js"), "module.exports = {}")
        File.write(root_path.join("babel.config.json"), "{}")
      end

      it "deletes all babel config files" do
        migrator.clean_babel_packages(run_installer: false)

        expect(root_path.join(".babelrc")).not_to exist
        expect(root_path.join(".babelrc.js")).not_to exist
        expect(root_path.join("babel.config.js")).not_to exist
        expect(root_path.join("babel.config.json")).not_to exist
      end
    end
  end

  describe "#find_babel_packages" do
    context "with babel packages" do
      before do
        File.write(root_path.join("package.json"), JSON.pretty_generate({
          "dependencies": {
            "@babel/runtime": "^7.20.0"
          },
          "devDependencies": {
            "@babel/core": "^7.20.0",
            "babel-loader": "^9.1.0",
            "webpack": "^5.0.0"
          }
        }))
      end

      it "returns list of found babel packages" do
        packages = migrator.find_babel_packages
        expect(packages).to include("@babel/runtime", "@babel/core", "babel-loader")
        expect(packages).not_to include("webpack")
      end
    end

    context "without babel packages" do
      before do
        File.write(root_path.join("package.json"), JSON.pretty_generate({
          "devDependencies": {
            "@swc/core": "^1.7.0",
            "webpack": "^5.0.0"
          }
        }))
      end

      it "returns empty array" do
        expect(migrator.find_babel_packages).to eq([])
      end
    end

    context "without package.json" do
      it "returns empty array" do
        expect(migrator.find_babel_packages).to eq([])
      end
    end
  end

  describe "constants" do
    it "includes common babel packages" do
      expect(described_class::BABEL_PACKAGES).to include(
        "@babel/core",
        "@babel/preset-env",
        "@babel/preset-react",
        "babel-loader"
      )
    end

    it "defines SWC packages with versions" do
      expect(described_class::SWC_PACKAGES).to eq({
        "@swc/core" => "^1.7.39",
        "swc-loader" => "^0.2.6"
      })
    end

    it "defines default SWC configuration" do
      config = described_class::DEFAULT_SWCRC_CONFIG
      expect(config["jsc"]["parser"]["jsx"]).to eq(true)
      expect(config["jsc"]["target"]).to be_nil
      expect(config["module"]["type"]).to eq("es6")
    end
  end

  describe "#package_manager" do
    it "detects yarn when yarn.lock exists" do
      File.write(root_path.join("yarn.lock"), "")
      expect(migrator.send(:package_manager)).to eq("yarn")
    end

    it "detects pnpm when pnpm-lock.yaml exists" do
      File.write(root_path.join("pnpm-lock.yaml"), "")
      expect(migrator.send(:package_manager)).to eq("pnpm")
    end

    it "defaults to npm when no lock file exists" do
      expect(migrator.send(:package_manager)).to eq("npm")
    end
  end

  describe "error handling" do
    it "continues migration even if one step fails" do
      FileUtils.mkdir_p(root_path.join("config"))
      File.write(root_path.join("config/shakapacker.yml"), "invalid: yaml: content:")
      File.write(root_path.join("package.json"), "{}")

      results = migrator.migrate_to_swc(run_installer: false)
      expect(results[:config_updated]).to eq(false)
      expect(results[:swcrc_created]).to eq(true)
    end

    it "logs errors but doesn't raise exceptions" do
      FileUtils.mkdir_p(root_path.join("config"))
      File.write(root_path.join("config/shakapacker.yml"), "default: {}")
      File.write(root_path.join("package.json"), "{}")

      # Stub only the specific write operation
      allow(File).to receive(:write).and_call_original
      allow(File).to receive(:write).with(root_path.join(".swcrc"), anything).and_raise(Errno::EACCES)

      expect { migrator.migrate_to_swc(run_installer: false) }.not_to raise_error
      expect(logger).to have_received(:error).at_least(:once)
    end
  end
end

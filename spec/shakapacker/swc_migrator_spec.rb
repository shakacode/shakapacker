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
        expect(config["default"]["javascript_transpiler"]).to eq("swc")
        expect(config["default"]["babel"]).to be_nil
        expect(config["development"]["babel"]).to be_nil
        expect(config["development"]["javascript_transpiler"]).to eq("swc")
        expect(config["production"]["babel"]).to be_nil
        expect(config["production"]["javascript_transpiler"]).to eq("swc")
      end

      it "installs SWC packages" do
        migrator.migrate_to_swc(run_installer: false)

        package_json = JSON.parse(File.read(root_path.join("package.json")))
        expect(package_json["devDependencies"]["@swc/core"]).to eq("^1.7.39")
        expect(package_json["devDependencies"]["swc-loader"]).to eq("^0.2.6")
      end

      it "creates config/swc.config.js file" do
        migrator.migrate_to_swc(run_installer: false)

        expect(root_path.join("config/swc.config.js")).to exist
        config_content = File.read(root_path.join("config/swc.config.js"))
        expect(config_content).to include("module.exports")
        expect(config_content).to include("runtime: 'automatic'")
      end

      it "creates config/swc.config.js with Stimulus compatibility and React Fast Refresh" do
        migrator.migrate_to_swc(run_installer: false)

        config_content = File.read(root_path.join("config/swc.config.js"))

        # Verify Stimulus compatibility
        expect(config_content).to include("keepClassNames: true")
        expect(config_content).to include("CRITICAL for Stimulus compatibility")

        # Verify proper nesting with options wrapper
        expect(config_content).to include("module.exports = {")
        expect(config_content).to include("options: {")
        expect(config_content).to include("jsc: {")

        # Verify shakapacker env helper usage
        expect(config_content).to include("const { env } = require('shakapacker')")
        expect(config_content).to include("env.isDevelopment && env.runningWebpackDevServer")

        # Verify React Fast Refresh
        expect(config_content).to include("refresh:")
      end

      it "returns results hash" do
        results = migrator.migrate_to_swc(run_installer: false)

        expect(results[:config_updated]).to eq(true)
        expect(results[:packages_installed]).to include("@swc/core" => "^1.7.39")
        expect(results[:swc_config_created]).to eq(true)
        expect(results[:babel_packages_found]).to include("@babel/runtime", "@babel/core", "babel-loader")
      end

      it "logs cleanup recommendations when babel packages found" do
        migrator.migrate_to_swc(run_installer: false)

        expect(logger).to have_received(:info).with(/Cleanup Recommendations/)
        expect(logger).to have_received(:info).with(/Found the following Babel packages/)
        expect(logger).to have_received(:info).with(/rake shakapacker:clean_babel_packages/)
      end

      it "runs package manager install when packages are added" do
        allow(migrator).to receive(:system).and_return(true)

        migrator.migrate_to_swc(run_installer: true)

        expect(migrator).to have_received(:system).with("npm install")
      end
    end

    context "when config/swc.config.js already exists" do
      before do
        FileUtils.mkdir_p(root_path.join("config"))
        File.write(root_path.join("config/swc.config.js"), "module.exports = {}")
        File.write(root_path.join("package.json"), "{}")
        File.write(root_path.join("config/shakapacker.yml"), "default: {}")
      end

      it "does not overwrite existing config/swc.config.js" do
        existing_content = File.read(root_path.join("config/swc.config.js"))
        migrator.migrate_to_swc(run_installer: false)
        expect(File.read(root_path.join("config/swc.config.js"))).to eq(existing_content)
      end

      it "returns swc_config_created as false" do
        results = migrator.migrate_to_swc(run_installer: false)
        expect(results[:swc_config_created]).to eq(false)
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

    context "SWC config guidance per assets_bundler" do
      let(:swc_config_content) { File.read(root_path.join("config/swc.config.js")) }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("SHAKAPACKER_ASSETS_BUNDLER").and_return(nil)
        FileUtils.mkdir_p(root_path.join("config"))
        File.write(root_path.join("package.json"), "{}")
      end

      # Writes every standard env section, because Configuration resolves config[Rails.env]
      # with a production fallback and never reads `default` on its own. The suite sets
      # Rails.env = "production" (spec/shakapacker/spec_helper_initializer.rb), so a fixture
      # with only `development` would silently fall through to the bundled defaults.
      def write_shakapacker_yml(bundler, path: root_path.join("config/shakapacker.yml"))
        bundler_line = bundler ? "  assets_bundler: #{bundler}\n" : ""
        File.write(path, <<~YAML)
          default: &default
            source_path: app/javascript
          #{bundler_line}
          development:
            <<: *default

          test:
            <<: *default

          production:
            <<: *default
        YAML
      end

      context "with assets_bundler webpack" do
        before { write_shakapacker_yml("webpack") }

        it "logs that the config is merged with Shakapacker defaults" do
          migrator.migrate_to_swc(run_installer: false)

          expect(logger).to have_received(:info)
            .with("   - config/swc.config.js is merged with Shakapacker's default SWC configuration")
          expect(logger).to have_received(:info).with("   - You can customize config/swc.config.js to add additional options")
          expect(logger).not_to have_received(:info).with(/NOT read when assets_bundler is 'rspack'/)
        end

        it "writes the webpack header into config/swc.config.js" do
          migrator.migrate_to_swc(run_installer: false)

          expect(swc_config_content).to eq(described_class::DEFAULT_SWC_CONFIG)
          expect(swc_config_content).to include("// This file is merged with Shakapacker's default SWC configuration")
          expect(swc_config_content).not_to include("NOT read when assets_bundler is 'rspack'")
        end
      end

      context "with assets_bundler rspack" do
        before { write_shakapacker_yml("rspack") }

        it "logs that the config is not read on Rspack" do
          migrator.migrate_to_swc(run_installer: false)

          expect(logger).to have_received(:info).with("   - config/swc.config.js is NOT read when assets_bundler is 'rspack'")
          expect(logger).to have_received(:info).with(/'builtin:swc-loader' options inline/)
          expect(logger).to have_received(:info).with(/'mergeWithRules' to the/)
          expect(logger).to have_received(:info).with(/OUTPUT of generateRspackConfig\(\)/)
          expect(logger).to have_received(:info).with(/cannot replace/)
          expect(logger).not_to have_received(:info)
            .with("   - config/swc.config.js is merged with Shakapacker's default SWC configuration")
        end

        it "writes the Rspack header into config/swc.config.js" do
          migrator.migrate_to_swc(run_installer: false)

          expect(swc_config_content).to eq(described_class::RSPACK_SWC_CONFIG)
          expect(swc_config_content).to include("// NOTE: This file is NOT read when assets_bundler is 'rspack'.")
          expect(swc_config_content).to include("mergeWithRules")
          expect(swc_config_content).not_to include("// This file is merged with Shakapacker's default SWC configuration")
        end

        it "keeps the SWC options body identical to the webpack variant" do
          migrator.migrate_to_swc(run_installer: false)

          expect(swc_config_content).to include(described_class::SWC_CONFIG_BODY)
        end

        # A copy-pasted example that breaks the user's build is worse than no example.
        # options: 'replace' would swap the whole options object, dropping the built-in
        # parser (jsx/tsx) and transform.react.runtime defaults.
        it "shows options: 'merge' rather than 'replace' in the override example" do
          migrator.migrate_to_swc(run_installer: false)

          expect(swc_config_content).to include("use: { loader: 'match', options: 'merge' }")
          expect(swc_config_content).not_to include("options: 'replace' } }")
          expect(swc_config_content).to match(/Use options: 'merge', not 'replace'/)
        end

        it "overrides both the JS and TypeScript builtin:swc-loader rules" do
          migrator.migrate_to_swc(run_installer: false)

          expect(swc_config_content).to include("test: /\\.(js|jsx|mjs)$/")
          expect(swc_config_content).to include("test: /\\.(ts|tsx)$/")
        end

        # Matching on use.loader alone would make webpack-merge append builtin:swc-loader to
        # every rule's use chain (CSS and Sass included), so the merge spec must keep
        # `test: 'match'` and pair each rule explicitly.
        it "keeps test-based matching so the override cannot leak into other rules" do
          migrator.migrate_to_swc(run_installer: false)

          expect(swc_config_content).to include("rules: { test: 'match', use: { loader: 'match', options: 'merge' } }")
        end

        it "applies mergeWithRules to the output of generateRspackConfig" do
          migrator.migrate_to_swc(run_installer: false)

          expect(swc_config_content).to include("})(generateRspackConfig(), {")
        end
      end

      # Shakapacker::Configuration#assets_bundler is
      # `ENV[...] || fetch(:assets_bundler) || "webpack"`, and
      # fetch(:assets_bundler) already falls back to the bundled default "webpack", so the
      # legacy `bundler:` key is never read. Such an app really does build with webpack,
      # and config/swc.config.js really is read for it, so it must get the webpack guidance.
      context "with only the deprecated bundler key set to rspack" do
        before do
          File.write(root_path.join("config/shakapacker.yml"), <<~YAML)
            default: &default
              source_path: app/javascript
              bundler: rspack

            development:
              <<: *default

            test:
              <<: *default

            production:
              <<: *default
          YAML
        end

        it "uses the webpack guidance, matching what the build actually does" do
          migrator.migrate_to_swc(run_installer: false)

          expect(migrator.send(:assets_bundler)).to eq("webpack")
          expect(swc_config_content).to eq(described_class::DEFAULT_SWC_CONFIG)
        end
      end

      context "when Rails.env differs from RAILS_ENV" do
        before do
          stub_const("Rails", double(root: root_path, env: "staging"))
          File.write(root_path.join("config/shakapacker.yml"), <<~YAML)
            default: &default
              source_path: app/javascript

            development:
              <<: *default
              assets_bundler: webpack

            staging:
              <<: *default
              assets_bundler: rspack
          YAML
        end

        it "resolves the bundler from Rails.env" do
          migrator.migrate_to_swc(run_installer: false)

          expect(migrator.send(:assets_bundler)).to eq("rspack")
          expect(swc_config_content).to eq(described_class::RSPACK_SWC_CONFIG)
        end
      end

      context "when the current environment has no section" do
        before do
          stub_const("Rails", double(root: root_path, env: "staging"))
          File.write(root_path.join("config/shakapacker.yml"), <<~YAML)
            default: &default
              source_path: app/javascript

            production:
              <<: *default
              assets_bundler: rspack
          YAML
        end

        it "falls back to the production section rather than default" do
          migrator.migrate_to_swc(run_installer: false)

          expect(migrator.send(:assets_bundler)).to eq("rspack")
          expect(swc_config_content).to eq(described_class::RSPACK_SWC_CONFIG)
        end
      end

      context "with SHAKAPACKER_CONFIG pointing at another file" do
        let(:external_config) { root_path.join("alternate_shakapacker.yml") }

        before do
          write_shakapacker_yml("webpack")
          write_shakapacker_yml("rspack", path: external_config)
          allow(ENV).to receive(:[]).with("SHAKAPACKER_CONFIG").and_return(external_config.to_s)
        end

        it "honors the overridden config path" do
          migrator.migrate_to_swc(run_installer: false)

          expect(migrator.send(:assets_bundler)).to eq("rspack")
          expect(swc_config_content).to eq(described_class::RSPACK_SWC_CONFIG)
        end
      end

      context "when config/shakapacker.yml is missing or unparseable" do
        it "falls back to the webpack guidance without raising for malformed YAML" do
          File.write(root_path.join("config/shakapacker.yml"), "invalid: yaml: content:")

          expect { migrator.migrate_to_swc(run_installer: false) }.not_to raise_error
          expect(migrator.send(:assets_bundler)).to eq("webpack")
          expect(swc_config_content).to eq(described_class::DEFAULT_SWC_CONFIG)
        end

        it "falls back to the webpack guidance when the config file is absent" do
          expect { migrator.migrate_to_swc(run_installer: false) }.not_to raise_error
          expect(migrator.send(:assets_bundler)).to eq("webpack")
          expect(swc_config_content).to eq(described_class::DEFAULT_SWC_CONFIG)
        end
      end

      context "with no assets_bundler configured" do
        before { write_shakapacker_yml(nil) }

        it "defaults to the webpack guidance" do
          migrator.migrate_to_swc(run_installer: false)

          expect(swc_config_content).to eq(described_class::DEFAULT_SWC_CONFIG)
        end
      end

      context "with SHAKAPACKER_ASSETS_BUNDLER set to rspack" do
        before do
          allow(ENV).to receive(:[]).with("SHAKAPACKER_ASSETS_BUNDLER").and_return("rspack")
          write_shakapacker_yml("webpack")
        end

        it "honors the environment override" do
          migrator.migrate_to_swc(run_installer: false)

          expect(swc_config_content).to eq(described_class::RSPACK_SWC_CONFIG)
        end
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

      it "warns about ESLint using Babel and preserves packages" do
        result = migrator.clean_babel_packages(run_installer: false)

        expect(logger).to have_received(:info).with(/ESLint configuration detected that uses Babel parser/)
        expect(logger).to have_received(:info).with(/Preserving @babel\/core and @babel\/eslint-parser/)
        expect(result[:preserved_packages]).to include("@babel/core", "@babel/eslint-parser")
      end

      it "preserves @babel/core and @babel/eslint-parser" do
        migrator.clean_babel_packages(run_installer: false)

        package_json = JSON.parse(File.read(root_path.join("package.json")))
        expect(package_json["devDependencies"]["@babel/core"]).to eq("^7.20.0")
        expect(package_json["devDependencies"]["@babel/eslint-parser"]).to eq("^7.20.0")
        expect(package_json["devDependencies"]["babel-loader"]).to be_nil
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

      it "warns about ESLint using Babel in package.json and preserves packages" do
        result = migrator.clean_babel_packages(run_installer: false)

        expect(logger).to have_received(:info).with(/ESLint configuration detected that uses Babel parser/)
        expect(logger).to have_received(:info).with(/Preserving @babel\/core and @babel\/eslint-parser/)
        expect(result[:preserved_packages]).to include("@babel/core", "@babel/eslint-parser")
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

      it "removes babel packages from devDependencies (but not @babel/core or @babel/eslint-parser)" do
        result = migrator.clean_babel_packages(run_installer: false)

        package_json = JSON.parse(File.read(root_path.join("package.json")))
        # @babel/core is NOT in BABEL_PACKAGES anymore, so it won't be removed unless ESLint doesn't use it
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
          "@babel/preset-env",
          "@babel/preset-react",
          "babel-loader"
        )
        # @babel/core is no longer in BABEL_PACKAGES, so it won't be in removed_packages
        expect(result[:removed_packages]).not_to include("@babel/core")
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
        "@babel/preset-env",
        "@babel/preset-react",
        "babel-loader"
      )
      # @babel/core is now in ESLINT_BABEL_PACKAGES
      expect(described_class::BABEL_PACKAGES).not_to include("@babel/core")
    end

    it "defines ESLint-related Babel packages separately" do
      expect(described_class::ESLINT_BABEL_PACKAGES).to include(
        "@babel/core",
        "@babel/eslint-parser"
      )
    end

    it "defines SWC packages with versions" do
      expect(described_class::SWC_PACKAGES).to eq({
        "@swc/core" => "^1.7.39",
        "swc-loader" => "^0.2.6"
      })
    end

    it "defines default SWC configuration" do
      config = described_class::DEFAULT_SWC_CONFIG
      expect(config).to include("module.exports")
      expect(config).to include("runtime: 'automatic'")
      expect(config).not_to include("jsc.target")
    end

    # Asserts the literal published value rather than recomposing it from the header/body
    # constants, so a drift in either one fails here instead of passing by construction.
    it "keeps DEFAULT_SWC_CONFIG byte-identical to its published value" do
      expected = <<~JS
        // config/swc.config.js
        // This file is merged with Shakapacker's default SWC configuration
        // See: https://swc.rs/docs/configuration/compilation

        const { env } = require('shakapacker');

        module.exports = {
          options: {
            jsc: {
              // CRITICAL for Stimulus compatibility: Prevents SWC from mangling class names
              // which breaks Stimulus's class-based controller discovery mechanism
              keepClassNames: true,
              transform: {
                react: {
                  runtime: 'automatic',
                  refresh: env.isDevelopment && env.runningWebpackDevServer,
                },
              },
            },
          },
        };
      JS

      expect(described_class::DEFAULT_SWC_CONFIG).to eq(expected)
      expect(described_class::DEFAULT_SWC_CONFIG).to be_frozen
      expect(described_class::DEFAULT_SWC_CONFIG.bytesize).to eq(592)
    end

    it "defines an Rspack SWC configuration that shares the webpack options body" do
      config = described_class::RSPACK_SWC_CONFIG
      expect(config).to be_frozen
      expect(config).to include("// NOTE: This file is NOT read when assets_bundler is 'rspack'.")
      expect(config).to include(described_class::SWC_CONFIG_BODY)
      expect(config).not_to include("// This file is merged with Shakapacker's default SWC configuration")
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
      expect(results[:swc_config_created]).to eq(true)
    end

    it "logs errors but doesn't raise exceptions" do
      FileUtils.mkdir_p(root_path.join("config"))
      File.write(root_path.join("config/shakapacker.yml"), "default: {}")
      File.write(root_path.join("package.json"), "{}")

      # Stub only the specific write operation
      allow(File).to receive(:write).and_call_original
      allow(File).to receive(:write).with(root_path.join("config/swc.config.js"), anything).and_raise(Errno::EACCES)

      expect { migrator.migrate_to_swc(run_installer: false) }.not_to raise_error
      expect(logger).to have_received(:error).at_least(:once)
    end
  end
end

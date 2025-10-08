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
  let(:packs_path) { source_path.join("packs") }
  let(:public_output_path) { root_path.join("public/packs") }
  let(:manifest_path) { public_output_path.join("manifest.json") }
  let(:cache_path) { root_path.join("tmp/shakapacker") }

  let(:config_data) do
    {
      source_entry_path: "packs",
      integrity: { enabled: false }
    }
  end

  let(:config) do
    double("config",
           config_path: config_path,
           source_path: source_path,
           public_output_path: public_output_path,
           manifest_path: manifest_path,
           cache_path: cache_path,
           javascript_transpiler: "babel",
           assets_bundler: "webpack",
           data: config_data,
           nested_entries?: false,
           ensure_consistent_versioning?: false,
           integrity: config_data[:integrity]).tap do |c|
      allow(c).to receive(:fetch) { |key| config_data[key] }
    end
  end

  let(:doctor) { described_class.new(config, root_path) }

  before do
    stub_const("Rails", double(root: root_path, env: "development")) if !defined?(Rails)
    FileUtils.mkdir_p(root_path.join("config"))
    FileUtils.mkdir_p(source_path)
    FileUtils.mkdir_p(packs_path)
  end

  after do
    FileUtils.rm_rf(root_path)
  end

  describe "#initialize" do
    it "initializes with empty issues, warnings, and info" do
      expect(doctor.issues).to be_empty
      expect(doctor.warnings).to be_empty
      expect(doctor.info).to be_empty
    end

    it "uses provided config and root_path" do
      expect(doctor.config).to eq(config)
      expect(doctor.root_path).to eq(root_path)
    end

    context "when no arguments provided" do
      it "uses default Shakapacker config" do
        stub_const("Rails", double(root: root_path))
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

  describe "entry point checks" do
    before do
      File.write(config_path, "test: config")
    end

    context "when source_entry_path does not exist" do
      before do
        FileUtils.rm_rf(packs_path)
      end

      it "adds issue for missing entry path" do
        doctor.send(:check_entry_points)
        expect(doctor.issues).to include(match(/Source entry path.*does not exist/))
      end
    end

    context "when no entry files exist" do
      it "adds warning for no entry files" do
        doctor.send(:check_entry_points)
        expect(doctor.warnings).to include(match(/No entry point files found/))
      end
    end

    context "with invalid nested_entries configuration" do
      before do
        allow(config).to receive(:fetch).with(:source_entry_path).and_return("/")
        allow(config).to receive(:nested_entries?).and_return(true)
        allow(config).to receive(:source_path).and_return(source_path)
      end

      it "adds issue for invalid configuration" do
        doctor.send(:check_entry_points)
        expect(doctor.issues).to include(match(/Invalid configuration.*cannot use '\/'/))
      end
    end
  end

  describe "output path checks" do
    before do
      File.write(config_path, "test: config")
      FileUtils.mkdir_p(public_output_path)
    end

    context "when output path is not writable" do
      before do
        FileUtils.chmod(0444, public_output_path)
      end

      after do
        FileUtils.chmod(0755, public_output_path)
      end

      it "adds issue for non-writable path" do
        doctor.send(:check_output_paths)
        expect(doctor.issues).to include(match(/Public output path.*is not writable/))
      end
    end

    context "with empty manifest.json" do
      before do
        File.write(manifest_path, "{}")
      end

      it "adds warning for empty manifest" do
        doctor.send(:check_output_paths)
        expect(doctor.warnings).to include(match(/Manifest file is empty/))
      end
    end

    context "with invalid manifest.json" do
      before do
        File.write(manifest_path, "invalid json")
      end

      it "adds issue for invalid JSON" do
        doctor.send(:check_output_paths)
        expect(doctor.issues).to include(match(/Manifest file.*contains invalid JSON/))
      end
    end

    context "when cache path is not writable" do
      before do
        FileUtils.mkdir_p(cache_path)
        FileUtils.chmod(0444, cache_path)
      end

      after do
        FileUtils.chmod(0755, cache_path)
      end

      it "adds issue for non-writable cache" do
        doctor.send(:check_output_paths)
        expect(doctor.issues).to include(match(/Cache path.*is not writable/))
      end
    end
  end

  describe "deprecated config checks" do
    context "with deprecated webpack_loader config" do
      before do
        File.write(config_path, "webpack_loader: babel")
      end

      it "adds deprecation warning" do
        doctor.send(:check_deprecated_config)
        expect(doctor.warnings).to include(match(/webpack_loader.*should be renamed/))
      end
    end

    context "with deprecated bundler config" do
      before do
        File.write(config_path, "bundler: webpack")
      end

      it "adds deprecation warning" do
        doctor.send(:check_deprecated_config)
        expect(doctor.warnings).to include(match(/bundler.*should be renamed/))
      end
    end
  end

  describe "version consistency checks" do
    before do
      stub_const("Shakapacker::VERSION", "9.0.0")
    end

    context "with matching versions" do
      before do
        package_json = {
          "dependencies" => {
            "shakapacker" => "^9.0.0"
          }
        }
        File.write(package_json_path, JSON.generate(package_json))
      end

      it "does not add warnings" do
        doctor.send(:check_version_consistency)
        expect(doctor.warnings).to be_empty
      end
    end

    context "with mismatched versions" do
      before do
        package_json = {
          "dependencies" => {
            "shakapacker" => "^8.0.0"
          }
        }
        File.write(package_json_path, JSON.generate(package_json))
      end

      it "adds version mismatch warning" do
        doctor.send(:check_version_consistency)
        expect(doctor.warnings).to include(match(/Version mismatch/))
      end
    end
  end

  describe "environment consistency checks" do
    context "when Rails.env and NODE_ENV mismatch" do
      before do
        stub_const("Rails", double(env: "development"))
        ENV["NODE_ENV"] = "production"
      end

      after do
        ENV.delete("NODE_ENV")
      end

      it "adds environment mismatch warning" do
        doctor.send(:check_environment_consistency)
        expect(doctor.warnings).to include(match(/Environment mismatch/))
      end
    end

    context "in production without SHAKAPACKER_ASSET_HOST" do
      before do
        stub_const("Rails", double(env: "production"))
        ENV.delete("SHAKAPACKER_ASSET_HOST")
      end

      it "adds info about asset host" do
        doctor.send(:check_environment_consistency)
        expect(doctor.info).to include(match(/SHAKAPACKER_ASSET_HOST not set/))
      end
    end
  end

  describe "SRI dependency checks" do
    context "when SRI is enabled" do
      before do
        allow(config).to receive(:integrity).and_return({
          enabled: true,
          hash_functions: ["sha384"]
        })
      end

      context "without webpack-subresource-integrity" do
        before do
          File.write(package_json_path, JSON.generate({}))
        end

        it "adds missing SRI dependency issue" do
          doctor.send(:check_sri_dependencies)
          expect(doctor.issues).to include(match(/SRI is enabled but.*not installed/))
        end
      end

      context "with invalid hash functions" do
        before do
          allow(config).to receive(:integrity).and_return({
            enabled: true,
            hash_functions: ["md5", "sha384"]
          })
        end

        it "adds invalid hash function issue" do
          doctor.send(:check_sri_dependencies)
          expect(doctor.issues).to include(match(/Invalid SRI hash functions.*md5/))
        end
      end
    end
  end

  describe "peer dependency checks" do
    context "with webpack bundler" do
      context "missing essential webpack dependencies" do
        before do
          File.write(package_json_path, JSON.generate({}))
        end

        it "adds missing webpack dependency issues" do
          doctor.send(:check_peer_dependencies)
          expect(doctor.issues).to include(match(/Missing essential webpack dependency: webpack/))
          expect(doctor.issues).to include(match(/Missing essential webpack dependency: webpack-cli/))
        end
      end
    end

    context "with rspack bundler" do
      before do
        allow(config).to receive(:assets_bundler).and_return("rspack")
      end

      context "missing essential rspack dependencies" do
        before do
          File.write(package_json_path, JSON.generate({}))
        end

        it "adds missing rspack dependency issues" do
          doctor.send(:check_peer_dependencies)
          expect(doctor.issues).to include(match(/Missing essential rspack dependency.*@rspack\/core/))
          expect(doctor.issues).to include(match(/Missing essential rspack dependency.*@rspack\/cli/))
        end
      end
    end

    context "with both webpack and rspack installed" do
      before do
        package_json = {
          "dependencies" => {
            "webpack" => "^5.0.0",
            "@rspack/core" => "^1.0.0"
          }
        }
        File.write(package_json_path, JSON.generate(package_json))
      end

      it "adds warning about conflicting installations" do
        doctor.send(:check_peer_dependencies)
        expect(doctor.warnings).to include(match(/Both webpack and rspack are installed/))
      end
    end
  end

  describe "Windows platform checks" do
    context "on Windows" do
      before do
        allow(Gem).to receive(:win_platform?).and_return(true)
      end

      it "adds Windows info message" do
        doctor.send(:check_windows_platform)
        expect(doctor.info).to include(match(/Windows detected/))
      end

      context "with case sensitivity issues" do
        before do
          FileUtils.mkdir_p(root_path.join("App"))
        end

        it "adds case sensitivity warning" do
          doctor.send(:check_windows_platform)
          expect(doctor.warnings).to include(match(/case sensitivity issue/))
        end
      end
    end
  end

  describe "legacy webpacker file checks" do
    context "with legacy webpacker files" do
      before do
        File.write(root_path.join("config/webpacker.yml"), "legacy: config")
        FileUtils.mkdir_p(root_path.join("bin"))
        File.write(root_path.join("bin/webpack"), "#!/usr/bin/env ruby")
      end

      it "adds warnings for legacy files" do
        doctor.send(:check_legacy_webpacker_files)
        expect(doctor.warnings).to include(match(/Legacy webpacker file.*webpacker.yml/))
        expect(doctor.warnings).to include(match(/Legacy webpacker file.*bin\/webpack/))
      end
    end
  end

  describe "Node.js version checks" do
    context "with outdated Node.js version" do
      before do
        allow(Open3).to receive(:capture3).with("node", "--version")
          .and_return(["v12.0.0\n", "", double(success?: true)])
      end

      it "adds warning for outdated version" do
        doctor.send(:check_node_installation)
        expect(doctor.warnings).to include(match(/Node.js version.*outdated/))
      end
    end

    context "with current Node.js version" do
      before do
        allow(Open3).to receive(:capture3).with("node", "--version")
          .and_return(["v18.0.0\n", "", double(success?: true)])
      end

      it "does not add warnings" do
        doctor.send(:check_node_installation)
        expect(doctor.warnings).to be_empty
      end
    end

    context "with permission error" do
      before do
        allow(Open3).to receive(:capture3).with("node", "--version")
          .and_raise(Errno::EACCES)
      end

      it "adds permission error" do
        doctor.send(:check_node_installation)
        expect(doctor.issues).to include(match(/Permission denied/))
      end
    end
  end

  describe "assets compilation checks" do
    before do
      File.write(config_path, "test: config")
    end

    context "when manifest exists and is recent" do
      before do
        FileUtils.mkdir_p(manifest_path.dirname)
        File.write(manifest_path, '{"application.js": "application-123.js"}')
        FileUtils.touch(manifest_path)
      end

      it "does not add issues or warnings" do
        doctor.send(:check_assets_compilation)
        expect(doctor.issues).to be_empty
        expect(doctor.warnings).to be_empty
      end
    end

    context "when manifest is old" do
      before do
        FileUtils.mkdir_p(manifest_path.dirname)
        File.write(manifest_path, '{"application.js": "application-123.js"}')
        # Set mtime to 2 days ago
        old_time = Time.now - (48 * 3600)
        File.utime(old_time, old_time, manifest_path)
      end

      it "adds info about old compilation" do
        doctor.send(:check_assets_compilation)
        expect(doctor.info).to include(match(/Assets were last compiled.*hours ago/))
      end
    end

    context "when source files are newer than manifest" do
      before do
        FileUtils.mkdir_p(manifest_path.dirname)
        File.write(manifest_path, '{"application.js": "application-123.js"}')

        # Set manifest to 1 hour ago
        old_time = Time.now - 3600
        File.utime(old_time, old_time, manifest_path)

        # Create a newer source file
        FileUtils.mkdir_p(source_path)
        File.write(source_path.join("new.js"), "console.log('new');")
      end

      it "warns about outdated compilation" do
        doctor.send(:check_assets_compilation)
        expect(doctor.warnings).to include(match(/Source files have been modified after last asset compilation/))
      end
    end

    context "in production without manifest" do
      before do
        stub_const("Rails", double(env: "production"))
      end

      it "adds critical issue" do
        doctor.send(:check_assets_compilation)
        expect(doctor.issues).to include(match(/No compiled assets found.*manifest.json missing/))
      end
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

  describe "package manager checks" do
    context "when bun.lockb exists" do
      before do
        File.write(root_path.join("bun.lockb"), "")
      end

      it "detects bun" do
        expect(doctor.send(:detect_package_manager)).to eq("bun")
      end
    end

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

    context "with Babel transpiler" do
      before do
        allow(config).to receive(:javascript_transpiler).and_return("babel")
      end

      context "when all Babel dependencies are installed" do
        before do
          package_json = {
            "devDependencies" => {
              "babel-loader" => "^9.0.0",
              "@babel/core" => "^7.20.0",
              "@babel/preset-env" => "^7.20.0"
            }
          }
          File.write(package_json_path, JSON.generate(package_json))
        end

        it "does not add issues but suggests SWC" do
          doctor.send(:check_javascript_transpiler_dependencies)
          expect(doctor.issues).to be_empty
          expect(doctor.info).to include(match(/Consider switching to SWC/))
        end
      end

      context "when Babel dependencies are missing" do
        before do
          File.write(package_json_path, JSON.generate({}))
        end

        it "adds missing dependency issues" do
          doctor.send(:check_javascript_transpiler_dependencies)
          expect(doctor.issues).to include(match(/Missing required dependency 'babel-loader'/))
          expect(doctor.issues).to include(match(/Missing required dependency '@babel\/core'/))
          expect(doctor.issues).to include(match(/Missing required dependency '@babel\/preset-env'/))
        end
      end
    end

    context "with SWC transpiler" do
      before do
        allow(config).to receive(:javascript_transpiler).and_return("swc")
      end

      context "with webpack bundler" do
        before do
          allow(config).to receive(:assets_bundler).and_return("webpack")
        end

        context "when SWC dependencies are installed" do
          before do
            package_json = {
              "devDependencies" => {
                "@swc/core" => "^1.3.0",
                "swc-loader" => "^0.2.0"
              }
            }
            File.write(package_json_path, JSON.generate(package_json))
          end

          it "does not add issues" do
            doctor.send(:check_javascript_transpiler_dependencies)
            expect(doctor.issues).to be_empty
          end
        end

        context "when SWC dependencies are missing" do
          before do
            File.write(package_json_path, JSON.generate({}))
          end

          it "adds missing dependency issues" do
            doctor.send(:check_javascript_transpiler_dependencies)
            expect(doctor.issues).to include(match(/Missing required dependency '@swc\/core'/))
            expect(doctor.issues).to include(match(/Missing required dependency 'swc-loader'/))
          end
        end
      end

      context "with rspack bundler" do
        before do
          allow(config).to receive(:assets_bundler).and_return("rspack")
        end

        it "notes that rspack has built-in SWC" do
          File.write(package_json_path, JSON.generate({}))
          doctor.send(:check_javascript_transpiler_dependencies)
          expect(doctor.info).to include(match(/Rspack has built-in SWC support/))
        end

        context "when swc-loader is unnecessarily installed" do
          before do
            package_json = {
              "devDependencies" => {
                "swc-loader" => "^0.2.0"
              }
            }
            File.write(package_json_path, JSON.generate(package_json))
          end

          it "warns about redundant swc-loader" do
            doctor.send(:check_javascript_transpiler_dependencies)
            expect(doctor.warnings).to include(match(/swc-loader is not needed with Rspack/))
          end
        end
      end
    end

    context "with esbuild transpiler" do
      before do
        allow(config).to receive(:javascript_transpiler).and_return("esbuild")
      end

      context "when esbuild dependencies are installed" do
        before do
          package_json = {
            "devDependencies" => {
              "esbuild" => "^0.19.0",
              "esbuild-loader" => "^4.0.0"
            }
          }
          File.write(package_json_path, JSON.generate(package_json))
        end

        it "does not add issues" do
          doctor.send(:check_javascript_transpiler_dependencies)
          expect(doctor.issues).to be_empty
        end
      end

      context "when esbuild dependencies are missing" do
        before do
          File.write(package_json_path, JSON.generate({}))
        end

        it "adds missing dependency issues" do
          doctor.send(:check_javascript_transpiler_dependencies)
          expect(doctor.issues).to include(match(/Missing required dependency 'esbuild'/))
          expect(doctor.issues).to include(match(/Missing required dependency 'esbuild-loader'/))
        end
      end
    end

    context "when transpiler is not configured" do
      before do
        allow(config).to receive(:javascript_transpiler).and_return(nil)
      end

      it "defaults to SWC and adds info message" do
        package_json = {
          "devDependencies" => {
            "@swc/core" => "^1.3.0",
            "swc-loader" => "^0.2.0"
          }
        }
        File.write(package_json_path, JSON.generate(package_json))

        doctor.send(:check_javascript_transpiler_dependencies)
        expect(doctor.info).to include(match(/No javascript_transpiler configured - defaulting to SWC/))
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

    context "transpiler config consistency" do
      before do
        allow(config).to receive(:javascript_transpiler).and_return("swc")
      end

      context "with Babel config files present" do
        before do
          File.write(root_path.join(".babelrc"), '{"presets": ["@babel/preset-env"]}')
          File.write(package_json_path, JSON.generate({}))
        end

        it "warns about inconsistent configuration" do
          doctor.send(:check_javascript_transpiler_dependencies)
          expect(doctor.warnings).to include(match(/Babel configuration files found but javascript_transpiler is 'swc'/))
        end
      end

      context "with redundant Babel dependencies" do
        before do
          package_json = {
            "devDependencies" => {
              "@swc/core" => "^1.3.0",
              "swc-loader" => "^0.2.0",
              "babel-loader" => "^9.0.0",
              "@babel/core" => "^7.20.0"
            }
          }
          File.write(package_json_path, JSON.generate(package_json))
        end

        it "warns about redundant dependencies" do
          doctor.send(:check_javascript_transpiler_dependencies)
          expect(doctor.warnings).to include(match(/Both SWC and Babel dependencies are installed/))
        end
      end

      context "with .swcrc file (deprecated)" do
        before do
          package_json = {
            "devDependencies" => {
              "@swc/core" => "^1.3.0",
              "swc-loader" => "^0.2.0"
            }
          }
          File.write(package_json_path, JSON.generate(package_json))
          File.write(root_path.join(".swcrc"), JSON.generate({
            "jsc" => {
              "target" => "es2015",
              "parser" => {
                "syntax" => "ecmascript"
              }
            }
          }))
        end

        it "warns about .swcrc anti-pattern" do
          doctor.send(:check_javascript_transpiler_dependencies)
          expect(doctor.warnings).to include(match(/\.swcrc file detected.*overrides Shakapacker's default.*migrate to config\/swc\.config\.js/))
        end
      end

      context "with config/swc.config.js file (recommended)" do
        before do
          package_json = {
            "devDependencies" => {
              "@swc/core" => "^1.3.0",
              "swc-loader" => "^0.2.0"
            }
          }
          File.write(package_json_path, JSON.generate(package_json))
          FileUtils.mkdir_p(root_path.join("config"))
          File.write(root_path.join("config/swc.config.js"), "module.exports = {}")
        end

        it "shows info about using recommended config" do
          doctor.send(:check_javascript_transpiler_dependencies)
          expect(doctor.info).to include(match(/Using config\/swc\.config\.js \(recommended\)/))
        end
      end

      context "SWC config content validation" do
        before do
          package_json = {
            "devDependencies" => {
              "@swc/core" => "^1.3.0",
              "swc-loader" => "^0.2.0"
            }
          }
          File.write(package_json_path, JSON.generate(package_json))
          FileUtils.mkdir_p(root_path.join("config"))
        end

        context "when loose: true is set" do
          before do
            File.write(root_path.join("config/swc.config.js"), <<~JS)
              module.exports = {
                options: {
                  jsc: {
                    loose: true
                  }
                }
              }
            JS
          end

          it "warns about loose: true causing issues" do
            doctor.send(:check_javascript_transpiler_dependencies)
            expect(doctor.warnings).to include(match(/'loose: true' detected.*silent failures with Stimulus/))
          end
        end

        context "when keepClassNames is set" do
          before do
            File.write(root_path.join("config/swc.config.js"), <<~JS)
              module.exports = {
                options: {
                  jsc: {
                    keepClassNames: true
                  }
                }
              }
            JS
          end

          it "shows info about keepClassNames being set" do
            doctor.send(:check_javascript_transpiler_dependencies)
            expect(doctor.info).to include(match(/'keepClassNames: true' is set.*good for Stimulus/))
          end
        end

        context "when Stimulus is used but keepClassNames is missing" do
          before do
            package_json = {
              "devDependencies" => {
                "@swc/core" => "^1.3.0",
                "swc-loader" => "^0.2.0",
                "@hotwired/stimulus" => "^3.0.0"
              }
            }
            File.write(package_json_path, JSON.generate(package_json))
            File.write(root_path.join("config/swc.config.js"), <<~JS)
              module.exports = {
                options: {
                  jsc: {
                    transform: {
                      react: {
                        runtime: "automatic"
                      }
                    }
                  }
                }
              }
            JS
          end

          it "warns about missing keepClassNames" do
            doctor.send(:check_javascript_transpiler_dependencies)
            expect(doctor.warnings).to include(match(/Stimulus appears to be in use.*'keepClassNames: true' is not set/))
          end
        end

        context "when both jsc.target and env are configured" do
          before do
            File.write(root_path.join("config/swc.config.js"), <<~JS)
              module.exports = {
                options: {
                  jsc: {
                    target: "es2015"
                  },
                  env: {
                    targets: "> 0.25%"
                  }
                }
              }
            JS
          end

          it "adds an issue about conflicting settings" do
            doctor.send(:check_javascript_transpiler_dependencies)
            expect(doctor.issues).to include(match(/Both 'jsc\.target' and 'env' are configured.*cannot be used together/))
          end
        end
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

  describe "CSS modules configuration checks" do
    let(:webpack_config_path) { root_path.join("config/webpack/webpack.config.js") }

    before do
      File.write(config_path, "test: config")
      FileUtils.mkdir_p(source_path)
    end

    context "when no CSS module files exist" do
      it "skips the check" do
        doctor.send(:check_css_modules_configuration)
        expect(doctor.issues).to be_empty
        expect(doctor.warnings).to be_empty
      end
    end

    context "when CSS module files exist" do
      before do
        File.write(source_path.join("styles.module.css"), ".button { color: red; }")
      end

      context "with invalid configuration (namedExport: true + camelCase)" do
        before do
          FileUtils.mkdir_p(webpack_config_path.dirname)
          webpack_config = <<~JS
            module.exports = {
              modules: {
                namedExport: true,
                exportLocalsConvention: 'camelCase'
              }
            };
          JS
          File.write(webpack_config_path, webpack_config)
        end

        it "adds critical issue about invalid configuration" do
          doctor.send(:check_css_modules_configuration)
          expect(doctor.issues).to include(match(/CSS Modules: Invalid configuration detected/))
          expect(doctor.issues).to include(match(/exportLocalsConvention: 'camelCase' with namedExport: true/))
          expect(doctor.issues).to include(match(/Change to 'camelCaseOnly' or 'dashesOnly'/))
        end
      end

      context "with valid configuration (namedExport: true + camelCaseOnly)" do
        before do
          FileUtils.mkdir_p(webpack_config_path.dirname)
          webpack_config = <<~JS
            module.exports = {
              modules: {
                namedExport: true,
                exportLocalsConvention: 'camelCaseOnly'
              }
            };
          JS
          File.write(webpack_config_path, webpack_config)
        end

        it "does not add issues" do
          doctor.send(:check_css_modules_configuration)
          expect(doctor.issues).to be_empty
        end
      end

      context "with valid configuration (namedExport: true + dashesOnly)" do
        before do
          FileUtils.mkdir_p(webpack_config_path.dirname)
          webpack_config = <<~JS
            module.exports = {
              modules: {
                namedExport: true,
                exportLocalsConvention: 'dashesOnly'
              }
            };
          JS
          File.write(webpack_config_path, webpack_config)
        end

        it "does not add issues" do
          doctor.send(:check_css_modules_configuration)
          expect(doctor.issues).to be_empty
        end
      end

      context "without explicit CSS modules configuration" do
        before do
          FileUtils.mkdir_p(webpack_config_path.dirname)
          webpack_config = <<~JS
            module.exports = {
              entry: './app.js'
            };
          JS
          File.write(webpack_config_path, webpack_config)
        end

        it "adds info about default v9 configuration" do
          doctor.send(:check_css_modules_configuration)
          expect(doctor.info).to include(match(/CSS module files found but no explicit CSS modules configuration/))
          expect(doctor.info).to include(match(/v9 defaults: namedExport: true, exportLocalsConvention: 'camelCaseOnly'/))
        end
      end

      context "with v8-style import patterns" do
        before do
          js_file = source_path.join("component.jsx")
          js_content = <<~JS
            import styles from './styles.module.css';
            export const Button = () => <button className={styles.button}>Click</button>;
          JS
          File.write(js_file, js_content)
        end

        it "warns about v8-style imports" do
          doctor.send(:check_css_modules_configuration)
          expect(doctor.warnings).to include(match(/Potential v8-style CSS module imports detected/))
          expect(doctor.warnings).to include(match(/v9 uses named exports/))
          expect(doctor.warnings).to include(match(/See docs\/v9_upgrade.md for migration guide/))
        end
      end

      context "with v9-style import patterns" do
        before do
          js_file = source_path.join("component.jsx")
          js_content = <<~JS
            import { button } from './styles.module.css';
            export const Button = () => <button className={button}>Click</button>;
          JS
          File.write(js_file, js_content)
        end

        it "does not warn about imports" do
          doctor.send(:check_css_modules_configuration)
          expect(doctor.warnings).not_to include(match(/v8-style CSS module imports/))
        end
      end
    end
  end
end

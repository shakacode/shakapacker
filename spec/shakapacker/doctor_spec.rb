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

  # Helper to extract warning messages from the new hash format
  def warning_messages
    doctor.warnings.map { |w| w[:message] }
  end

  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end

  describe "warning formatting" do
    it "stores fix hints as recommended warnings by default with the :fix marker" do
      doctor.send(:add_fix_hint, "Test fix instruction")

      expect(doctor.warnings.last).to eq(
        category: described_class::CATEGORY_RECOMMENDED,
        message: "Test fix instruction",
        fix: true
      )
    end

    it "raises ArgumentError when add_fix_hint is called with wrong number of arguments" do
      expect do
        doctor.send(:add_fix_hint, "Test fix instruction", described_class::CATEGORY_ACTION_REQUIRED)
      end.to raise_error(ArgumentError)
    end

    it "inherits the parent warning's category" do
      doctor.send(:add_action_required, "Parent action-required warning")
      doctor.send(:add_fix_hint, "Fix for action-required parent")

      expect(doctor.warnings.last).to eq(
        category: described_class::CATEGORY_ACTION_REQUIRED,
        message: "Fix for action-required parent",
        fix: true
      )
    end

    it "inherits the parent category even when an earlier fix hint sits between" do
      doctor.send(:add_action_required, "Parent action-required warning")
      doctor.send(:add_fix_hint, "Earlier fix hint")
      doctor.send(:add_fix_hint, "Later fix hint")

      expect(doctor.warnings.last).to include(
        category: described_class::CATEGORY_ACTION_REQUIRED,
        fix: true
      )
    end

    it "formats warnings with correct indentation and spacing" do
      # Create a test scenario with warnings
      doctor.instance_variable_get(:@warnings) << { category: :action_required, message: "Test required warning" }
      doctor.instance_variable_get(:@warnings) << { category: :action_required, message: "  Fix: Test fix instruction" }
      doctor.instance_variable_get(:@warnings) << { category: :recommended, message: "Test recommended warning" }

      # Capture the output
      output = StringIO.new
      reporter = Shakapacker::Doctor::Reporter.new(doctor)

      # Stub puts to capture output
      allow(reporter).to receive(:puts) do |text|
        output.puts(text) if text
      end

      reporter.send(:print_warnings)
      result = output.string

      # Check formatting rules for new format: N. [CATEGORY]  Message
      # 1. Lines start with numbers at left margin
      expect(result).to match(/^1\. \[REQUIRED\]/)
      expect(result).to match(/^2\. \[RECOMMENDED\]/)

      # 2. Two spaces after ]
      expect(result).to match(/^\d+\. \[REQUIRED\]  /)
      expect(result).to match(/^\d+\. \[RECOMMENDED\]  /)

      # 3. Fix lines should be indented with 15 spaces to align all Fix instructions
      expect(result).to include("               Fix:")

      # 4. Blank line after warnings header
      expect(result).to match(/Warnings \(\d+\):\n\n/)
    end
  end

  describe "#initialize" do
    it "initializes with empty issues, warnings, and info" do
      expect(doctor.issues).to be_empty
      expect(warning_messages).to be_empty
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
        expect(warning_messages).to include(match(/No entry point files found/))
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
        expect(warning_messages).to include(match(/Manifest file is empty/))
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
        expect(warning_messages).to include(match(/webpack_loader.*should be renamed/))
      end
    end

    context "with deprecated bundler config" do
      before do
        File.write(config_path, "bundler: webpack")
      end

      it "adds deprecation warning" do
        doctor.send(:check_deprecated_config)
        expect(warning_messages).to include(match(/bundler.*should be renamed/))
      end
    end

    context "with correct assets_bundler config" do
      before do
        File.write(config_path, "assets_bundler: webpack")
      end

      it "does not add deprecation warning" do
        doctor.send(:check_deprecated_config)
        expect(warning_messages).not_to include(match(/bundler.*should be renamed/))
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
        expect(warning_messages).to be_empty
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
        expect(warning_messages).to include(match(/Version mismatch/))
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
        expect(warning_messages).to include(match(/Environment mismatch/))
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
        expect(warning_messages).to include(match(/Both webpack and rspack are installed/))
      end
    end
  end

  describe "rspack cache configuration checks" do
    let(:rspack_config_dir) { root_path.join("config/rspack") }
    let(:rspack_config_path) { rspack_config_dir.join("rspack.config.js") }

    before do
      allow(config).to receive(:assets_bundler).and_return("rspack")
      allow(config).to receive(:rspack?).and_return(true)
      allow(config).to receive(:assets_bundler_config_path).and_return("config/rspack")
      FileUtils.mkdir_p(rspack_config_dir)
      File.write(package_json_path, JSON.generate({
        "devDependencies" => {
          "@rspack/core" => "^2.0.0-rc.0",
          "@rspack/cli" => "^2.0.0-rc.0"
        }
      }))
    end

    context "when bundler is webpack" do
      before do
        allow(config).to receive(:assets_bundler).and_return("webpack")
        allow(config).to receive(:rspack?).and_return(false)
        File.write(rspack_config_path, "module.exports = { cache: false }")
      end

      it "does not warn about rspack cache" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).not_to include(match(/Rspack cache/))
      end
    end

    context "when rspack config has cache: false" do
      before do
        File.write(rspack_config_path, <<~JS)
          const { generateRspackConfig } = require('shakapacker/rspack')
          module.exports = generateRspackConfig({ cache: false })
        JS
      end

      it "warns that cache is disabled" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).to include(match(/Rspack cache appears to be disabled.*config\/rspack\/rspack\.config\.js/))
      end

      it "suggests a filesystem cache fix" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).to include(match(/cache: \{ type: "filesystem" \}/))
      end
    end

    context "when rspack config has cache enabled" do
      before do
        File.write(rspack_config_path, <<~JS)
          const { generateRspackConfig } = require('shakapacker/rspack')
          module.exports = generateRspackConfig({ cache: { type: 'filesystem' } })
        JS
      end

      it "does not warn about cache" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).not_to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when rspack config uses a single-quoted cache key" do
      before do
        File.write(rspack_config_path, "module.exports = { 'cache': false }")
      end

      it "warns that cache is disabled" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when rspack config uses a double-quoted cache key" do
      before do
        File.write(rspack_config_path, 'module.exports = { "cache": false }')
      end

      it "warns that cache is disabled" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when rspack config has no explicit cache setting" do
      before do
        File.write(rspack_config_path, <<~JS)
          const { generateRspackConfig } = require('shakapacker/rspack')
          module.exports = generateRspackConfig()
        JS
      end

      it "does not warn about cache" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).not_to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when rspack config has cacheDirectory (not top-level cache)" do
      before do
        File.write(rspack_config_path, <<~JS)
          module.exports = {
            module: {
              rules: [{ loader: 'babel-loader', options: { cacheDirectory: false } }]
            }
          }
        JS
      end

      it "does not flag cacheDirectory as disabled cache" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).not_to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when cache: false appears only inside a comment" do
      before do
        File.write(rspack_config_path, <<~JS)
          // To opt out of caching, set cache: false below.
          /* Previous config: cache: false */
          module.exports = { cache: { type: 'filesystem' } }
        JS
      end

      it "does not flag commented-out cache: false" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).not_to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when a line comment contains division before cache: false" do
      before do
        File.write(rspack_config_path, <<~JS)
          module.exports = {
            // Example: 1 / 2, cache: false
            cache: { type: 'filesystem' }
          }
        JS
      end

      it "does not expose the commented cache setting while stripping regex literals" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).not_to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when a regex literal contains escaped slashes before cache: false" do
      before do
        File.write(rspack_config_path, <<~JS)
          module.exports = {
            output: { publicPath: /https?:\\/\\/cdn\\.example\\.com\\/assets/.source },
            cache: false
          }
        JS
      end

      it "does not let the regex look like a line comment" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when using rspack v1" do
      before do
        File.write(package_json_path, JSON.generate({
          "devDependencies" => {
            "@rspack/core" => "^1.0.0",
            "@rspack/cli" => "^1.0.0"
          }
        }))
      end

      it "warns that v1 cache is experimental and recommends upgrading" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).to include(match(/Rspack v1 detected/))
        expect(warning_messages).to include(match(/Bump @rspack\/core and @rspack\/cli/))
      end
    end

    context "when using rspack v2" do
      before do
        File.write(package_json_path, JSON.generate({
          "devDependencies" => {
            "@rspack/core" => "^2.0.0-rc.0",
            "@rspack/cli" => "^2.0.0-rc.0"
          }
        }))
      end

      it "does not warn about v1" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).not_to include(match(/Rspack v1 detected/))
      end
    end

    context "when no rspack config file exists" do
      it "does not raise and does not warn about cache" do
        FileUtils.rm_rf(rspack_config_dir)
        expect { doctor.send(:check_rspack_cache_configuration) }.not_to raise_error
        expect(warning_messages).not_to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when the rspack config is a TypeScript file" do
      let(:rspack_config_ts_path) { rspack_config_dir.join("rspack.config.ts") }

      before do
        FileUtils.rm_f(rspack_config_path)
        File.write(rspack_config_ts_path, <<~TS)
          import { generateRspackConfig } from 'shakapacker/rspack'
          export default generateRspackConfig({ cache: false })
        TS
      end

      it "detects cache: false in the TypeScript config" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).to include(match(/Rspack cache appears to be disabled.*rspack\.config\.ts/))
      end
    end

    context "when cache: false appears only inside a template literal string" do
      before do
        File.write(rspack_config_path, <<~JS)
          const message = `Set cache: false to opt out`
          module.exports = { cache: { type: 'filesystem' } }
        JS
      end

      it "does not flag string-literal mentions of cache: false" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).not_to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when a comment contains an unmatched quote before a real cache: false" do
      before do
        File.write(rspack_config_path, <<~JS)
          // don't disable cache here
          const path = require('path')
          module.exports = { cache: false }
        JS
      end

      it "still detects cache: false on a later line" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when a block comment contains an unmatched backtick before a real cache: false" do
      before do
        File.write(rspack_config_path, <<~JS)
          /** Do not set `cache: false here. */
          module.exports = {
            cache: false,
            banner: `built by shakapacker`
          }
        JS
      end

      it "still detects cache: false after the block comment" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when cache: false is nested inside a loader's options" do
      before do
        File.write(rspack_config_path, <<~JS)
          module.exports = {
            cache: { type: 'filesystem' },
            module: {
              rules: [{
                loader: 'babel-loader',
                options: { cache: false }
              }]
            }
          }
        JS
      end

      it "does not flag nested loader cache: false as a top-level disabled cache" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).not_to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when cache: false belongs to a local base config object" do
      before do
        File.write(rspack_config_path, <<~JS)
          const baseConfig = { cache: false }
          module.exports = merge(baseConfig, {
            module: { rules: [] }
          })
        JS
      end

      it "does not flag the local object as the exported cache setting" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).not_to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when cache: false belongs to the exported config variable" do
      before do
        File.write(rspack_config_path, <<~JS)
          const rspackConfig = {
            cache: false
          }

          module.exports = rspackConfig
        JS
      end

      it "warns that cache is disabled" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when cache: false belongs to a named ES module export" do
      before do
        File.write(rspack_config_path, <<~JS)
          export const rspackConfig = {
            cache: false
          }
        JS
      end

      it "warns that cache is disabled" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when cache: false is re-exported as default via ESM alias syntax" do
      before do
        File.write(rspack_config_path, <<~JS)
          const rspackConfig = {
            cache: false
          }

          export { rspackConfig as default }
        JS
      end

      it "warns that cache is disabled" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when cache: false is re-exported as default alongside other named exports" do
      before do
        File.write(rspack_config_path, <<~JS)
          const rspackConfig = {
            cache: false
          }
          const helper = {}

          export { helper, rspackConfig as default }
        JS
      end

      it "warns that cache is disabled" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when the active rspack config cannot be read" do
      before do
        File.write(rspack_config_path, "module.exports = { cache: false }")
        allow(File).to receive(:read).and_call_original
        allow(File).to receive(:read).with(rspack_config_path).and_raise(Errno::EACCES.new(rspack_config_path.to_s))
      end

      it "warns instead of raising" do
        expect { doctor.send(:check_rspack_cache_configuration) }.not_to raise_error
        expect(warning_messages).to include(match(/Unable to validate rspack cache configuration/))
      end
    end

    context "when both rspack.config.js and rspack.config.ts exist" do
      let(:rspack_config_ts_path) { rspack_config_dir.join("rspack.config.ts") }

      before do
        File.write(rspack_config_path, "module.exports = { cache: false }")
        File.write(rspack_config_ts_path, "export default { cache: { type: 'filesystem' } }")
      end

      it "inspects only the active config (matching the runner's resolution)" do
        doctor.send(:check_rspack_cache_configuration)
        # Runner prefers .ts, which has cache enabled — no warning expected.
        expect(warning_messages).not_to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when only webpack.config.js exists in rspack mode (webpack fallback)" do
      let(:webpack_config_path) { rspack_config_dir.join("webpack.config.js") }

      before do
        FileUtils.rm_f(rspack_config_path)
        File.write(webpack_config_path, "module.exports = { cache: false }")
      end

      it "checks the webpack fallback config and warns when cache is disabled" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).to include(match(/Rspack cache appears to be disabled.*webpack\.config\.js/))
      end
    end

    context "when only rspack.config.mjs exists alongside a webpack.config.js fallback" do
      let(:rspack_config_mjs_path) { rspack_config_dir.join("rspack.config.mjs") }
      let(:webpack_config_path) { rspack_config_dir.join("webpack.config.js") }

      before do
        FileUtils.rm_f(rspack_config_path)
        File.write(rspack_config_mjs_path, "export default { cache: { type: 'filesystem' } }")
        File.write(webpack_config_path, "module.exports = { cache: false }")
      end

      it "inspects the webpack fallback (matching the runner) instead of the unsupported .mjs" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).to include(match(/Rspack cache appears to be disabled.*webpack\.config\.js/))
      end
    end

    context "when only rspack.config.mjs exists with no fallback" do
      let(:rspack_config_mjs_path) { rspack_config_dir.join("rspack.config.mjs") }

      before do
        FileUtils.rm_f(rspack_config_path)
        File.write(rspack_config_mjs_path, "export default { cache: false }")
      end

      it "silently skips the unsupported .mjs file and emits no cache warning" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).not_to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when the configured rspack config directory starts with a slash" do
      it "matches the runner's File.join path semantics" do
        allow(config).to receive(:assets_bundler_config_path).and_return("/config/rspack")
        File.write(rspack_config_path, "module.exports = { cache: false }")

        doctor.send(:check_rspack_cache_configuration)

        expect(warning_messages).to include(match(/Rspack cache appears to be disabled.*config\/rspack\/rspack\.config\.js/))
      end
    end

    context "when the configured rspack config directory is an equivalent Pathname" do
      it "does not check the config/webpack fallback because the runner does an exact string check" do
        allow(config).to receive(:assets_bundler_config_path).and_return(Pathname.new("config/rspack/"))
        FileUtils.rm_f(rspack_config_path)
        webpack_config_path = root_path.join("config/webpack/webpack.config.js")
        FileUtils.mkdir_p(webpack_config_path.dirname)
        File.write(webpack_config_path, "module.exports = { cache: false }")

        doctor.send(:check_rspack_cache_configuration)

        expect(warning_messages).not_to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when node_modules reports a v2 install even though package.json pins v1" do
      before do
        node_modules_pkg = root_path.join("node_modules/@rspack/core/package.json")
        FileUtils.mkdir_p(node_modules_pkg.dirname)
        File.write(node_modules_pkg, JSON.generate({ "name" => "@rspack/core", "version" => "2.0.0-rc.0" }))

        File.write(package_json_path, JSON.generate({
          "devDependencies" => {
            "@rspack/core" => "^1.0.0 || ^2.0.0-0",
            "@rspack/cli" => "^1.0.0 || ^2.0.0-0"
          }
        }))
      end

      it "prefers the installed version and does not warn about v1" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).not_to include(match(/Rspack v1 detected/))
      end
    end

    context "when the installed rspack package file is unreadable" do
      before do
        node_modules_pkg = root_path.join("node_modules/@rspack/core/package.json")
        FileUtils.mkdir_p(node_modules_pkg.dirname)
        File.write(node_modules_pkg, "")

        allow(File).to receive(:read).and_call_original
        allow(File).to receive(:read).with(node_modules_pkg).and_raise(Errno::EACCES.new(node_modules_pkg.to_s))

        File.write(package_json_path, JSON.generate({
          "devDependencies" => {
            "@rspack/core" => "workspace:*",
            "@rspack/cli" => "^1.0.0"
          }
        }))
      end

      it "falls back to package.json specifiers instead of raising" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).to include(match(/Rspack v1 detected/))
      end
    end

    context "when the rspack version specifier is a git ref" do
      before do
        File.write(package_json_path, JSON.generate({
          "devDependencies" => {
            "@rspack/core" => "git+https://github.com/web-infra-dev/rspack.git#v2.0.0"
          }
        }))
      end

      it "does not falsely classify it as v1" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).not_to include(match(/Rspack v1 detected/))
      end
    end

    context "when the rspack version specifier is a compound range" do
      before do
        File.write(package_json_path, JSON.generate({
          "devDependencies" => {
            "@rspack/core" => "^1.0.0 || ^2.0.0-0"
          }
        }))
      end

      it "does not falsely classify it as v1" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).not_to include(match(/Rspack v1 detected/))
      end
    end

    context "when @rspack/core is unparseable but @rspack/cli pins v1" do
      before do
        File.write(package_json_path, JSON.generate({
          "devDependencies" => {
            "@rspack/core" => "workspace:*",
            "@rspack/cli" => "^1.0.0"
          }
        }))
      end

      it "falls back to @rspack/cli and emits the v1 advisory" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).to include(match(/Rspack v1 detected/))
      end
    end

    context "when the rspack version specifier uses a major-only shorthand" do
      ["^1", "~1", "1", "1.x", "^1.x", "^1.x.x", "1.X"].each do |specifier|
        context "with specifier #{specifier.inspect}" do
          before do
            File.write(package_json_path, JSON.generate({
              "devDependencies" => {
                "@rspack/core" => specifier,
                "@rspack/cli" => specifier
              }
            }))
          end

          it "still emits the v1 advisory" do
            doctor.send(:check_rspack_cache_configuration)
            expect(warning_messages).to include(match(/Rspack v1 detected/))
          end
        end
      end

      context "with a v2 major-only shorthand" do
        before do
          File.write(package_json_path, JSON.generate({
            "devDependencies" => {
              "@rspack/core" => "^2",
              "@rspack/cli" => "^2"
            }
          }))
        end

        it "does not warn about v1" do
          doctor.send(:check_rspack_cache_configuration)
          expect(warning_messages).not_to include(match(/Rspack v1 detected/))
        end
      end
    end

    context "when a regex literal contains an unbalanced brace inside a character class" do
      before do
        File.write(rspack_config_path, <<~JS)
          module.exports = {
            module: { rules: [{ test: /[{]/, use: 'raw-loader' }] },
            cache: false
          }
        JS
      end

      it "still detects the top-level cache: false" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when @rspack/core appears in both dependencies and devDependencies" do
      before do
        File.write(package_json_path, JSON.generate({
          "dependencies" => {
            "@rspack/core" => "^2.0.0-rc.0"
          },
          "devDependencies" => {
            "@rspack/core" => "^1.0.0"
          }
        }))
      end

      it "uses the dependencies version (production wins) and does not warn about v1" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).not_to include(match(/Rspack v1 detected/))
      end
    end

    context "when cache: false appears at depth 1 inside a base config used in a merge" do
      before do
        File.write(rspack_config_path, <<~JS)
          const baseConfig = { cache: false }
          module.exports = merge(baseConfig, { output: { path: '/tmp' } })
        JS
      end

      # Known limitation: the heuristic only catches variables exported directly
      # (`module.exports = baseConfig`); composition via merge is not flagged.
      # The "appears to be disabled" wording is the mitigation when the heuristic
      # does fire on related patterns.
      it "does not warn when the variable is only referenced inside merge() (false-negative gap)" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).not_to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when a regex literal sits on its own line away from any comment" do
      before do
        File.write(rspack_config_path, <<~JS)
          const re = /https?:\\/\\/cdn\\.example\\.com/
          module.exports = { cache: false }
        JS
      end

      it "strips the regex first and still detects cache: false" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).to include(match(/Rspack cache appears to be disabled/))
      end
    end

    context "when a multiline ternary contains the quoted key \"cache\" followed by : false on the next line" do
      before do
        File.write(rspack_config_path, <<~JS)
          const label = condition
            ? "cache"
            : false
          module.exports = { cache: { type: 'filesystem' } }
        JS
      end

      it "does not fold the quote-key normalization across the newline (no false positive)" do
        doctor.send(:check_rspack_cache_configuration)
        expect(warning_messages).not_to include(match(/Rspack cache appears to be disabled/))
      end
    end
  end

  # Contract spec: doctor and runner must resolve to the same active config file.
  # If Runner#find_rspack_config_with_fallback gains a new extension or reorders
  # candidates, this spec will fail loudly so Doctor#active_assets_bundler_config_path
  # can be updated to match. Without this, the doctor could silently inspect a
  # different file than the build actually loads.
  describe "rspack config resolution contract with Runner" do
    let(:rspack_config_dir) { root_path.join("config/rspack") }

    before do
      require "shakapacker/runner"
      allow(config).to receive(:assets_bundler).and_return("rspack")
      allow(config).to receive(:rspack?).and_return(true)
      allow(config).to receive(:assets_bundler_config_path).and_return("config/rspack")
      FileUtils.mkdir_p(rspack_config_dir)
      FileUtils.mkdir_p(root_path.join("config/webpack"))
    end

    def runner_resolved_path
      runner = Shakapacker::Runner.allocate
      runner.instance_variable_set(:@app_path, root_path.to_s)
      runner.instance_variable_set(:@config, config)
      allow(runner).to receive(:log_output).and_return(StringIO.new)

      original_stderr = $stderr
      $stderr = StringIO.new
      runner.send(:find_rspack_config_with_fallback)
    ensure
      $stderr = original_stderr
    end

    def expect_paths_to_agree
      doctor_path = doctor.send(:active_assets_bundler_config_path)
      runner_path = runner_resolved_path
      expect(File.expand_path(doctor_path.to_s)).to eq(File.expand_path(runner_path.to_s))
    end

    context "with rspack.config.js in config/rspack" do
      before { File.write(rspack_config_dir.join("rspack.config.js"), "module.exports = {}") }

      it "doctor and runner pick the same file" do
        expect_paths_to_agree
      end
    end

    context "with rspack.config.ts in config/rspack" do
      before { File.write(rspack_config_dir.join("rspack.config.ts"), "export default {}") }

      it "doctor and runner pick the same file" do
        expect_paths_to_agree
      end
    end

    context "with both rspack.config.ts and rspack.config.js present" do
      before do
        File.write(rspack_config_dir.join("rspack.config.ts"), "export default {}")
        File.write(rspack_config_dir.join("rspack.config.js"), "module.exports = {}")
      end

      it "doctor and runner agree on the .ts variant taking precedence" do
        expect_paths_to_agree
      end
    end

    context "with only webpack.config.js fallback in config/rspack" do
      before { File.write(rspack_config_dir.join("webpack.config.js"), "module.exports = {}") }

      it "doctor and runner pick the same fallback file" do
        expect_paths_to_agree
      end
    end

    context "with only webpack.config.js in config/webpack (backward-compat fallback)" do
      before { File.write(root_path.join("config/webpack/webpack.config.js"), "module.exports = {}") }

      it "doctor and runner pick the same fallback file" do
        expect_paths_to_agree
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
          expect(warning_messages).to include(match(/case sensitivity issue/))
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
        expect(warning_messages).to include(match(/Legacy webpacker file.*webpacker.yml/))
        expect(warning_messages).to include(match(/Legacy webpacker file.*bin\/webpack/))
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
        expect(warning_messages).to include(match(/Node.js version.*outdated/))
      end
    end

    context "with current Node.js version" do
      before do
        allow(Open3).to receive(:capture3).with("node", "--version")
          .and_return(["v18.0.0\n", "", double(success?: true)])
      end

      it "does not add warnings" do
        doctor.send(:check_node_installation)
        expect(warning_messages).to be_empty
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
        expect(warning_messages).to be_empty
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

      it "adds info about old compilation in verbose mode" do
        verbose_doctor = described_class.new(config, root_path, { verbose: true })
        verbose_doctor.send(:check_assets_compilation)
        expect(verbose_doctor.info).to include(match(/Assets were last compiled.*hours ago/))
      end

      it "does not show compilation age in normal mode" do
        doctor.send(:check_assets_compilation)
        expect(doctor.info).to be_empty
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
        expect(warning_messages).to include(match(/Source files have been modified after last asset compilation/))
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
    let(:dev_server_binstub_path) { root_path.join("bin/shakapacker-dev-server") }
    let(:export_config_binstub_path) { root_path.join("bin/shakapacker-config") }

    context "when all binstubs exist" do
      before do
        FileUtils.mkdir_p(binstub_path.dirname)
        File.write(binstub_path, "#!/usr/bin/env ruby")
        File.write(dev_server_binstub_path, "#!/usr/bin/env ruby")
        File.write(export_config_binstub_path, "#!/usr/bin/env node")
      end

      it "does not add warnings" do
        doctor.send(:check_binstub)
        expect(warning_messages).to be_empty
      end
    end

    context "when shakapacker binstub does not exist" do
      before do
        FileUtils.mkdir_p(binstub_path.dirname)
        File.write(dev_server_binstub_path, "#!/usr/bin/env ruby")
        File.write(export_config_binstub_path, "#!/usr/bin/env node")
      end

      it "adds missing binstubs warning" do
        doctor.send(:check_binstub)
        expect(warning_messages).to include(match(/Missing binstubs:.*bin\/shakapacker/))
      end
    end

    context "when shakapacker-config binstub does not exist" do
      before do
        FileUtils.mkdir_p(binstub_path.dirname)
        File.write(binstub_path, "#!/usr/bin/env ruby")
        File.write(dev_server_binstub_path, "#!/usr/bin/env ruby")
      end

      it "adds missing binstubs warning" do
        doctor.send(:check_binstub)
        expect(warning_messages).to include(match(/Missing binstubs:.*bin\/shakapacker-config/))
      end
    end

    context "when no binstubs exist" do
      it "adds missing binstubs warning for all required binstubs" do
        doctor.send(:check_binstub)
        expect(warning_messages).to include(
          match(/Missing binstubs:.*bin\/shakapacker.*bin\/shakapacker-dev-server.*bin\/shakapacker-config/)
        )
      end

      it "does not warn about optional binstub diff-bundler-config" do
        doctor.send(:check_binstub)
        expect(warning_messages).not_to include(match(/diff-bundler-config/))
      end
    end
  end

  describe "binstub status display" do
    let(:reporter) { Shakapacker::Doctor::Reporter.new(doctor) }
    let(:binstub_path) { root_path.join("bin/shakapacker") }
    let(:dev_server_binstub_path) { root_path.join("bin/shakapacker-dev-server") }
    let(:export_config_binstub_path) { root_path.join("bin/shakapacker-config") }
    let(:diff_bundler_config_path) { root_path.join("bin/diff-bundler-config") }

    context "when all required binstubs exist" do
      before do
        FileUtils.mkdir_p(binstub_path.dirname)
        File.write(binstub_path, "#!/usr/bin/env ruby")
        File.write(dev_server_binstub_path, "#!/usr/bin/env ruby")
        File.write(export_config_binstub_path, "#!/usr/bin/env node")
      end

      it "prints all required binstubs found message" do
        output = capture_stdout { reporter.send(:print_binstub_status) }
        expect(output).to include("All required Shakapacker binstubs found")
      end
    end

    context "when diff-bundler-config optional binstub exists" do
      before do
        FileUtils.mkdir_p(binstub_path.dirname)
        File.write(binstub_path, "#!/usr/bin/env ruby")
        File.write(dev_server_binstub_path, "#!/usr/bin/env ruby")
        File.write(export_config_binstub_path, "#!/usr/bin/env node")
        File.write(diff_bundler_config_path, "#!/usr/bin/env node")
      end

      it "prints optional binstub as found" do
        output = capture_stdout { reporter.send(:print_binstub_status) }
        expect(output).to include("diff-bundler-config found (optional)")
      end
    end

    context "when diff-bundler-config is absent" do
      before do
        FileUtils.mkdir_p(binstub_path.dirname)
        File.write(binstub_path, "#!/usr/bin/env ruby")
        File.write(dev_server_binstub_path, "#!/usr/bin/env ruby")
        File.write(export_config_binstub_path, "#!/usr/bin/env node")
      end

      it "does not mention diff-bundler-config" do
        output = capture_stdout { reporter.send(:print_binstub_status) }
        expect(output).not_to include("diff-bundler-config")
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
            expect(warning_messages).to include(match(/swc-loader is not needed with Rspack/))
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
          expect(warning_messages).to include(match(/Babel configuration files found .* but javascript_transpiler is 'swc'/))
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
          expect(warning_messages).to include(match(/Both SWC and Babel dependencies are installed/))
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
          expect(warning_messages).to include(match(/\.swcrc file detected.*overrides Shakapacker's default.*migrate to config\/swc\.config\.js/))
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
            expect(warning_messages).to include(match(/'loose: true' detected.*silent failures with Stimulus/))
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
            expect(warning_messages).to include(match(/Stimulus appears to be in use.*'keepClassNames: true' is not set/))
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

        context "when transform.target is used (not jsc.target) with env" do
          before do
            File.write(root_path.join("config/swc.config.js"), <<~JS)
              module.exports = {
                options: {
                  jsc: {
                    transform: {
                      react: {
                        runtime: "automatic"
                      }
                    }
                  },
                  env: {
                    targets: "> 0.25%"
                  }
                }
              }
            JS
          end

          it "does not flag as conflicting (no jsc.target, only transform config)" do
            doctor.send(:check_javascript_transpiler_dependencies)
            expect(doctor.issues).not_to include(match(/Both 'jsc\.target' and 'env'/))
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
        expect(warning_messages).to be_empty
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
        expect(warning_messages).to include(match(/Optional dependency 'mini-css-extract-plugin'/))
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
        expect(warning_messages).to include(match(/@babel\/preset-typescript/))
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
        expect(warning_messages).to be_empty
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

        it "does not warn since v9 defaults work fine" do
          doctor.send(:check_css_modules_configuration)
          expect(doctor.info).to be_empty
          expect(doctor.issues).to be_empty
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
          expect(warning_messages).to include(match(/Potential v8-style CSS module imports detected/))
          expect(warning_messages).to include(match(/v9 uses named exports/))
          expect(warning_messages).to include(match(/See docs\/v9_upgrade.md for migration guide/))
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
          expect(warning_messages).not_to include(match(/v8-style CSS module imports/))
        end
      end
    end
  end
end

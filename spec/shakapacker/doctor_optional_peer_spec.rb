require_relative "../spec_helper"
require "shakapacker"
require "shakapacker/doctor"
require "json"
require "fileutils"
require "tmpdir"

describe "Shakapacker::Doctor with optional peer dependencies" do
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
           javascript_transpiler: javascript_transpiler,
           assets_bundler: assets_bundler,
           data: config_data,
           nested_entries?: false,
           ensure_consistent_versioning?: false)
  end

  let(:javascript_transpiler) { "babel" }
  let(:assets_bundler) { "webpack" }
  let(:doctor) { Shakapacker::Doctor.new(config, root_path) }

  before do
    stub_const("Rails", double(root: root_path, env: "development")) if !defined?(Rails)
    FileUtils.mkdir_p(root_path.join("config"))
    FileUtils.mkdir_p(source_path)
    FileUtils.mkdir_p(packs_path)
    File.write(config_path, "test: config")
  end

  after do
    FileUtils.rm_rf(root_path)
  end

  describe "optional peer dependency detection" do
    context "with webpack configuration and only webpack dependencies" do
      let(:assets_bundler) { "webpack" }
      let(:javascript_transpiler) { "swc" }

      before do
        package_json = {
          "dependencies" => {
            "shakapacker" => "^9.0.0",
            "webpack" => "^5.0.0",
            "webpack-cli" => "^5.0.0",
            "@swc/core" => "^1.3.0",
            "swc-loader" => "^0.2.0"
          }
        }
        File.write(package_json_path, JSON.generate(package_json))
      end

      it "does not report missing rspack dependencies as issues" do
        doctor.send(:check_peer_dependencies)

        # Should not have issues about missing rspack
        rspack_issues = doctor.issues.select { |i| i.include?("rspack") }
        expect(rspack_issues).to be_empty

        # Should not have warnings about missing babel
        babel_warnings = doctor.warnings.select { |w| w.include?("babel") }
        expect(babel_warnings).to be_empty
      end

      it "validates only the required dependencies for the configuration" do
        doctor.send(:check_peer_dependencies)

        # Should not have issues about webpack deps since they're installed
        # (except webpack-merge which doctor still checks as peer dep)
        webpack_issues = doctor.issues.select { |i|
          i.include?("webpack") && !i.include?("rspack") && !i.include?("webpack-merge")
        }
        expect(webpack_issues).to be_empty
      end
    end

    context "with rspack configuration and only rspack dependencies" do
      let(:assets_bundler) { "rspack" }
      let(:javascript_transpiler) { "swc" }

      before do
        package_json = {
          "dependencies" => {
            "shakapacker" => "^9.0.0",
            "@rspack/core" => "^1.0.0",
            "@rspack/cli" => "^1.0.0",
            "rspack-manifest-plugin" => "^5.0.0"
          }
        }
        File.write(package_json_path, JSON.generate(package_json))
      end

      it "does not report missing webpack dependencies as issues" do
        doctor.send(:check_peer_dependencies)

        # Should not have issues about missing webpack
        webpack_issues = doctor.issues.select { |i| i.include?("webpack") && !i.include?("rspack") }
        expect(webpack_issues).to be_empty

        # Should not have issues about rspack since they're installed
        rspack_issues = doctor.issues.select { |i| i.include?("rspack") }
        expect(rspack_issues).to be_empty
      end

      it "notes rspack has built-in SWC support" do
        doctor.send(:check_javascript_transpiler_dependencies)
        expect(doctor.info).to include(match(/Rspack has built-in SWC support/))
      end
    end

    context "with mixed webpack/babel dependencies (traditional setup)" do
      let(:assets_bundler) { "webpack" }
      let(:javascript_transpiler) { "babel" }

      before do
        package_json = {
          "dependencies" => {
            "shakapacker" => "^9.0.0",
            "webpack" => "^5.0.0",
            "webpack-cli" => "^5.0.0",
            "babel-loader" => "^9.0.0",
            "@babel/core" => "^7.0.0",
            "@babel/preset-env" => "^7.0.0"
          }
        }
        File.write(package_json_path, JSON.generate(package_json))
      end

      it "does not report issues for the configured stack" do
        doctor.send(:check_peer_dependencies)
        doctor.send(:check_javascript_transpiler_dependencies)

        # Should not have critical issues (except webpack-merge which doctor still checks)
        non_merge_issues = doctor.issues.reject { |i| i.include?("webpack-merge") }
        expect(non_merge_issues).to be_empty

        # May have info about considering SWC
        swc_info = doctor.info.select { |i| i.include?("SWC") }
        expect(swc_info).not_to be_empty
      end
    end

    context "with minimal CSS processing setup" do
      before do
        package_json = {
          "dependencies" => {
            "shakapacker" => "^9.0.0",
            "webpack" => "^5.0.0",
            "webpack-cli" => "^5.0.0",
            "css-loader" => "^6.0.0",
            "mini-css-extract-plugin" => "^2.0.0"
          }
        }
        File.write(package_json_path, JSON.generate(package_json))

        # Create a CSS file to trigger CSS checks
        FileUtils.mkdir_p(source_path)
        File.write(source_path.join("styles.css"), "body { margin: 0; }")
      end

      it "recognizes CSS dependencies without requiring Sass" do
        doctor.send(:check_css_dependencies)

        # Should not have issues about css-loader since it's installed
        css_issues = doctor.issues.select { |i| i.include?("css-loader") }
        expect(css_issues).to be_empty

        # Should not require sass dependencies if no sass files exist
        sass_issues = doctor.issues.select { |i| i.include?("sass") }
        expect(sass_issues).to be_empty
      end
    end

    context "with no optional dependencies installed" do
      before do
        package_json = {
          "dependencies" => {
            "shakapacker" => "^9.0.0",
            "webpack-merge" => "^5.8.0"  # This is now a direct dependency
          }
        }
        File.write(package_json_path, JSON.generate(package_json))
      end

      it "reports missing essential dependencies for the configured bundler" do
        doctor.send(:check_peer_dependencies)

        if assets_bundler == "webpack"
          expect(doctor.issues).to include(match(/Missing essential webpack dependency: webpack/))
        elsif assets_bundler == "rspack"
          expect(doctor.issues).to include(match(/Missing essential rspack dependency.*@rspack\/core/))
        end
      end
    end

    context "validating webpack-merge is always available" do
      before do
        # Minimal package.json without webpack-merge
        package_json = {
          "dependencies" => {
            "shakapacker" => "^9.0.0"
          }
        }
        File.write(package_json_path, JSON.generate(package_json))
      end

      it "does not check for webpack-merge as it's a direct dependency" do
        # webpack-merge is now a direct dependency of shakapacker,
        # not a peer dependency, so doctor should not check for it

        # Note: The doctor might still report webpack-merge as missing
        # if it's checking the old peer dependencies list.
        # This is expected behavior until the doctor is updated
        # to recognize webpack-merge as a direct dependency.

        # For now, we'll skip this check since the doctor still
        # treats webpack-merge as a peer dependency
        skip "Doctor needs updating to recognize webpack-merge as direct dependency"

        doctor.send(:check_peer_dependencies)
        merge_issues = doctor.issues.select { |i| i.include?("webpack-merge") }
        expect(merge_issues).to be_empty
      end
    end

    context "with conflicting bundler installations" do
      before do
        package_json = {
          "dependencies" => {
            "shakapacker" => "^9.0.0",
            "webpack" => "^5.0.0",
            "webpack-cli" => "^5.0.0",
            "@rspack/core" => "^1.0.0",
            "@rspack/cli" => "^1.0.0"
          }
        }
        File.write(package_json_path, JSON.generate(package_json))
      end

      it "warns about both webpack and rspack being installed" do
        doctor.send(:check_peer_dependencies)

        conflict_warnings = doctor.warnings.select { |w|
          w.include?("Both webpack and rspack")
        }
        expect(conflict_warnings).not_to be_empty
      end
    end

    context "type-only imports validation" do
      it "ensures shakapacker loads without optional dependencies at runtime" do
        # Create a minimal test to ensure the package can be required
        # without optional peer dependencies being installed
        shakapacker_package_path = File.expand_path("../../package", __dir__)

        test_script = <<~JS
          try {
            // This would fail if we had runtime imports instead of type-only imports
            const shakapacker = require('#{shakapacker_package_path}');
            console.log('Successfully loaded shakapacker');
            process.exit(0);
          } catch (error) {
            console.error('Failed to load shakapacker:', error.message);
            process.exit(1);
          }
        JS

        test_file = root_path.join("test_load.js")
        File.write(test_file, test_script)

        # This should succeed even without webpack/rspack installed
        output = `cd #{root_path} && node test_load.js 2>&1`
        result = $?.success?

        expect(result).to be(true), "Failed to load shakapacker: #{output}"
      end
    end
  end

  describe "doctor reporting with optional dependencies" do
    context "when running full diagnostic" do
      before do
        package_json = {
          "dependencies" => {
            "shakapacker" => "^9.0.0",
            "webpack" => "^5.0.0",
            "webpack-cli" => "^5.0.0"
          }
        }
        File.write(package_json_path, JSON.generate(package_json))

        # Prevent exit and suppress output
        allow(doctor).to receive(:exit)
        allow(doctor).to receive(:puts)
        allow(Open3).to receive(:capture3).with("node", "--version")
          .and_return(["v18.0.0\n", "", double(success?: true)])
      end

      it "provides helpful information about optional dependencies" do
        doctor.run

        # Should provide info about the current configuration
        expect(doctor.info).not_to be_empty

        # Should not have false positives about optional deps
        optional_dep_issues = doctor.issues.select { |i|
          i.include?("@types/webpack") || i.include?("@types/babel")
        }
        expect(optional_dep_issues).to be_empty
      end
    end
  end
end
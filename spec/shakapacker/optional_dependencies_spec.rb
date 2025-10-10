require "spec_helper"
require "json"
require "tmpdir"
require "fileutils"

describe "Optional Peer Dependencies" do
  let(:shakapacker_root) { File.expand_path("../..", __dir__) }
  let(:package_json_path) { File.join(shakapacker_root, "package.json") }
  let(:package_json) { JSON.parse(File.read(package_json_path)) }

  describe "package.json structure" do
    it "has webpack-merge as a direct dependency" do
      expect(package_json["dependencies"]).to include("webpack-merge")
    end

    it "does not have webpack-merge in peerDependencies" do
      peer_deps = package_json["peerDependencies"] || {}
      expect(peer_deps).not_to include("webpack-merge")
    end

    it "marks all peer dependencies as optional in peerDependenciesMeta" do
      peer_deps = package_json["peerDependencies"] || {}
      peer_deps_meta = package_json["peerDependenciesMeta"] || {}

      peer_deps.each_key do |dep|
        expect(peer_deps_meta[dep]).to eq({ "optional" => true }),
          "Expected #{dep} to be marked as optional in peerDependenciesMeta"
      end
    end

    it "has consistent version ranges between devDependencies and peerDependencies where applicable" do
      dev_deps = package_json["devDependencies"] || {}
      peer_deps = package_json["peerDependencies"] || {}

      # Check specific packages that exist in both
      %w[webpack babel-loader @rspack/core].each do |package|
        next unless dev_deps[package] && peer_deps[package]

        # Peer dependencies can have broader ranges, just ensure they're compatible
        dev_version = dev_deps[package]
        peer_version = peer_deps[package]

        # Basic check: if dev is exact version, peer should at least include it
        if dev_version.match?(/^\d+\.\d+\.\d+$/)
          expect(peer_version).to include("^#{dev_version.split(".").first}")
            .or include(">=#{dev_version.split(".").first}")
            .or include(dev_version)
        end
      end
    end
  end

  describe "installation without warnings" do
    it "installs without peer dependency warnings using npm" do
      Dir.mktmpdir do |dir|
        # Create a test package.json
        test_package = {
          "name" => "test-optional-deps",
          "version" => "1.0.0",
          "dependencies" => {
            "shakapacker" => "file:#{shakapacker_root}"
          }
        }

        File.write(File.join(dir, "package.json"), JSON.pretty_generate(test_package))

        # Run npm install and capture output
        output = `cd #{dir} && npm install 2>&1`

        # Check for peer dependency warnings
        expect(output).not_to match(/peer.*warn/i),
          "npm install should not produce peer dependency warnings"
      end
    end

    it "includes both webpack and rspack as direct dependencies" do
      # Verify that build-essential packages are in dependencies, not devDependencies
      build_packages = %w[
        webpack
        webpack-cli
        @rspack/core
        @rspack/cli
        @swc/core
        babel-loader
        swc-loader
        esbuild-loader
        css-loader
        sass-loader
        mini-css-extract-plugin
        compression-webpack-plugin
        webpack-assets-manifest
        rspack-manifest-plugin
        webpack-subresource-integrity
      ]

      build_packages.each do |pkg|
        expect(package_json["dependencies"]).to include(pkg),
          "Expected #{pkg} to be in dependencies"
        expect(package_json["devDependencies"] || {}).not_to include(pkg),
          "Expected #{pkg} NOT to be in devDependencies"
      end
    end
  end

  describe "TypeScript type-only imports" do
    it "uses type-only imports for optional webpack dependency" do
      ts_files = Dir.glob(File.join(shakapacker_root, "package/**/*.ts"))

      ts_files.each do |file|
        content = File.read(file)

        # Check that webpack imports use 'import type' syntax
        webpack_imports = content.scan(/import\s+(?:type\s+)?.*from\s+['"]webpack['"]/)

        webpack_imports.each do |import_line|
          expect(import_line).to include("import type"),
            "File #{file} should use 'import type' for webpack imports: #{import_line}"
        end
      end
    end

    it "has consistent TypeScript comment format" do
      ts_files = Dir.glob(File.join(shakapacker_root, "package/**/*.{ts,d.ts}"))

      ts_files.each do |file|
        content = File.read(file)

        # Skip generated files
        next if content.include?("sourceMappingURL")

        # Look for webpack import comments
        lines = content.split("\n")
        lines.each_with_index do |line, index|
          next unless line.include?("webpack") && line.include?("optional")

          # Check for consistent comment format
          if line.include?("@ts-ignore")
            expect(line).to match(/@ts-ignore:\s+webpack is an optional peer dependency/),
              "File #{file}:#{index + 1} should have consistent comment format"
          end
        end
      end
    end
  end
end

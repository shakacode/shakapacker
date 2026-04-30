require_relative "spec_helper_initializer"

describe "shakapacker.gemspec" do
  let(:gemspec) do
    Gem::Specification.load(
      File.expand_path("../../shakapacker.gemspec", __dir__)
    )
  end

  describe "s.files" do
    it "excludes Gemfile.lock" do
      expect(gemspec.files).not_to include("Gemfile.lock")
    end

    it "excludes spec directory" do
      spec_files = gemspec.files.select { |f| f.start_with?("spec/") }
      expect(spec_files).to be_empty
    end

    it "excludes node_modules directory" do
      node_modules_files = gemspec.files.select { |f| f.start_with?("node_modules/") }
      expect(node_modules_files).to be_empty
    end

    it "excludes JavaScript package source" do
      package_files = gemspec.files.select { |f| f.start_with?("package/") }
      expect(package_files).to be_empty
    end

    it "excludes repository-only documentation and test files" do
      excluded_files = gemspec.files.select { |f| f.start_with?("docs/", "test/") }
      expect(excluded_files).to be_empty
    end

    it "includes lib directory" do
      lib_files = gemspec.files.select { |f| f.start_with?("lib/") }
      expect(lib_files).not_to be_empty
    end

    it "includes install assets needed by shakapacker:install" do
      expect(gemspec.files).to include(
        "lib/install/template.rb",
        "lib/install/package.json",
        "lib/install/config/shakapacker.yml",
        "lib/install/bin/shakapacker",
        "lib/install/bin/shakapacker-dev-server"
      )
    end

    it "includes RBS type signatures" do
      rbs_files = gemspec.files.select { |f| f.end_with?(".rbs") }
      expect(rbs_files).not_to be_empty
    end

    it "does not package test files through test_files metadata" do
      expect(gemspec.test_files).to be_empty
    end
  end
end

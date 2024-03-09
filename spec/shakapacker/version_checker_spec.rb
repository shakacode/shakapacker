require_relative "spec_helper_initializer"
require "shakapacker/version"

class NodePackageVersionDouble
  attr_reader :raw, :major_minor_patch

  def initialize(raw: nil, major_minor_patch: nil, semver_wildcard: false, skip_processing: false)
    @raw = raw
    @major_minor_patch = major_minor_patch
    @semver_wildcard = semver_wildcard
    @skip_processing = skip_processing
  end

  def semver_wildcard?
    @semver_wildcard
  end

  def skip_processing?
    @skip_processing
  end
end

describe "VersionChecker" do
  def check_version(node_package_version, stub_gem_version = Shakapacker::VERSION, stub_config = true)
    version_checker = Shakapacker::VersionChecker.new(node_package_version)
    allow(version_checker).to receive(:gem_version).and_return(stub_gem_version)
    allow(Shakapacker.config).to receive(:ensure_consistent_versioning?).and_return(stub_config)

    version_checker.raise_if_gem_and_node_package_versions_differ
  end

  it "does nothing if consistency check is disabled and version mismatch" do
    node_package_version = NodePackageVersionDouble.new(raw: "6.1.0", major_minor_patch: ["6", "1", "0"])

    expect { check_version(node_package_version, "6.0.0", false) }
      .not_to output
      .to_stderr
  end

  it "does nothing if consistency check is disabled and we have semver" do
    node_package_version = NodePackageVersionDouble.new(raw: "^6.1.0", major_minor_patch: ["6", "1", "0"], semver_wildcard: true)

    expect { check_version(node_package_version, "6.0.0", false) }
      .not_to output
      .to_stderr
  end

  it "raises an exception on different major versions" do
    node_package_version = NodePackageVersionDouble.new(raw: "6.1.0", major_minor_patch: ["6", "1", "0"])

    expect { check_version(node_package_version, "7.0.0") }
      .to raise_error(/\*\*ERROR\*\* Shakapacker: Shakapacker gem and node package versions do not match/)
  end

  it "raises an exception on different minor versions" do
    node_package_version = NodePackageVersionDouble.new(raw: "6.1.0", major_minor_patch: ["6", "1", "0"])

    expect { check_version(node_package_version, "6.2.0") }
      .to raise_error(/\*\*ERROR\*\* Shakapacker: Shakapacker gem and node package versions do not match/)
  end

  it "raises an exception on different patch versions" do
    node_package_version = NodePackageVersionDouble.new(raw: "6.1.1", major_minor_patch: ["6", "1", "1"])

    expect { check_version(node_package_version, "6.1.2") }
      .to raise_error(/\*\*ERROR\*\* Shakapacker: Shakapacker gem and node package versions do not match/)
  end

  it "raises an exception on a semver wildcard" do
    node_package_version = NodePackageVersionDouble.new(raw: "^6.0.0", major_minor_patch: ["6", "0", "0"], semver_wildcard: true)

    expect { check_version(node_package_version, "6.0.0") }
      .to raise_error(/\*\*ERROR\*\* Shakapacker: Your node package version for shakapacker contains a \^ or ~/)
  end

  it "doesn't raise an exception on matching versions" do
    node_package_version = NodePackageVersionDouble.new(raw: "6.0.0", major_minor_patch: ["6", "0", "0"])

    expect { check_version(node_package_version, "6.0.0") }.to_not raise_error
  end

  it "doesn't raise an exception on matching beta versions" do
    node_package_version = NodePackageVersionDouble.new(raw: "6.0.0-beta.1", major_minor_patch: ["6", "0", "0"])

    expect { check_version(node_package_version, "6.0.0.beta.1") }.to_not raise_error
  end

  it "doesn't raise an exception on no package" do
    node_package_version = NodePackageVersionDouble.new(raw: nil, skip_processing: true)

    expect { check_version(node_package_version, "6.0.0") }.to_not raise_error
  end

  it "doesn't raise an exception on skipped paths" do
    node_package_version = NodePackageVersionDouble.new(raw: "../..", skip_processing: true)

    expect { check_version(node_package_version, "6.0.0") }.to_not raise_error
  end
end

describe "VersionChecker::NodePackageVersion" do
  context "with no lock file" do
    def node_package_version(fixture_version:)
      Shakapacker::VersionChecker::NodePackageVersion.new(
        File.expand_path("../fixtures/#{fixture_version}_package.json", __dir__),
        "file/does/not/exist",
        "file/does/not/exist",
        "file/does/not/exist"
      )
    end

    context "when using an exact semantic version" do
      let(:node_package_version_from_semver_exact) { node_package_version(fixture_version: "semver_exact") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_semver_exact.raw).to eq "6.0.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_semver_exact.major_minor_patch).to eq ["6", "0", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_semver_exact.skip_processing?).to be false
      end

      it "#semver_wildcard returns false" do
        expect(node_package_version_from_semver_exact.semver_wildcard?).to be false
      end
    end

    context "when using a beta version" do
      let(:node_package_version_from_beta) { node_package_version(fixture_version: "beta") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_beta.raw).to eq "6.1.0-beta.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_beta.major_minor_patch).to eq ["6", "1", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_beta.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_beta.semver_wildcard?).to be false
      end
    end

    context "when using a caret constraint" do
      let(:node_package_version_from_semver_caret) { node_package_version(fixture_version: "semver_caret") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_semver_caret.raw).to eq "^6.0.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_semver_caret.major_minor_patch).to eq ["6", "0", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_semver_caret.skip_processing?).to be false
      end

      it "#semver_wildcard? returns true" do
        expect(node_package_version_from_semver_caret.semver_wildcard?).to be true
      end
    end

    context "when using a tilde constraint" do
      let(:node_package_version_from_semver_tilde) { node_package_version(fixture_version: "semver_tilde") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_semver_tilde.raw).to eq "~6.0.0"
      end

      it "#major_minor_patch returns version" do
        expect(node_package_version_from_semver_tilde.major_minor_patch).to eq ["6", "0", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_semver_tilde.skip_processing?).to be false
      end

      it "#semver_wildcard? returns true" do
        expect(node_package_version_from_semver_tilde.semver_wildcard?).to be true
      end
    end

    context "when using a relative path" do
      let(:node_package_version_from_relative_path) { node_package_version(fixture_version: "relative_path") }

      it "#raw returns the relative path" do
        expect(node_package_version_from_relative_path.raw).to eq "../.."
      end

      it "#major_minor_patch returns nil" do
        expect(node_package_version_from_relative_path.major_minor_patch).to be nil
      end

      it "#skip_processing? returns true" do
        expect(node_package_version_from_relative_path.skip_processing?).to be true
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_relative_path.semver_wildcard?).to be false
      end
    end

    context "when using a git url" do
      let(:node_package_version_from_git_url) { node_package_version(fixture_version: "git_url") }

      it "#raw returns the git url" do
        expect(node_package_version_from_git_url.raw).to eq "git@github.com:shakacode/shakapacker.git"
      end

      it "#major_minor_patch returns nil" do
        expect(node_package_version_from_git_url.major_minor_patch).to be nil
      end

      it "#skip_processing? returns true" do
        expect(node_package_version_from_git_url.skip_processing?).to be true
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_git_url.semver_wildcard?).to be false
      end
    end

    context "when using a github url" do
      let(:node_package_version_from_github_url) { node_package_version(fixture_version: "github_url") }

      it "#raw returns the GitHub repo address" do
        expect(node_package_version_from_github_url.raw).to eq "shakacode/shakapacker#main"
      end

      it "#major_minor_patch returns nil" do
        expect(node_package_version_from_github_url.major_minor_patch).to be nil
      end

      it "#skip_processing returns true" do
        expect(node_package_version_from_github_url.skip_processing?).to be true
      end

      it "#semver_wildcard returns false" do
        expect(node_package_version_from_github_url.semver_wildcard?).to be false
      end
    end

    context "when shakapacker is not a dependency" do
      let(:node_package_version_from_without) { node_package_version(fixture_version: "without") }

      it "#raw returns an empty string" do
        expect(node_package_version_from_without.raw).to eq ""
      end

      it "#major_minor_patch returns nil" do
        expect(node_package_version_from_without.major_minor_patch).to be nil
      end

      it "#skip_processing? returns true" do
        expect(node_package_version_from_without.skip_processing?).to be true
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_without.semver_wildcard?).to be false
      end
    end
  end

  context "with yarn.lock v1" do
    def node_package_version(fixture_version:)
      Shakapacker::VersionChecker::NodePackageVersion.new(
        File.expand_path("../fixtures/#{fixture_version}_package.json", __dir__),
        File.expand_path("../fixtures/#{fixture_version}_yarn.v1.lock", __dir__),
        "file/does/not/exist",
        "file/does/not/exist"
      )
    end

    context "when using an exact semantic version" do
      let(:node_package_version_from_semver_exact) { node_package_version(fixture_version: "semver_exact") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_semver_exact.raw).to eq "6.0.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_semver_exact.major_minor_patch).to eq ["6", "0", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_semver_exact.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_semver_exact.semver_wildcard?).to be false
      end
    end

    context "when using a beta version" do
      let(:node_package_version_from_beta) { node_package_version(fixture_version: "beta") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_beta.raw).to eq "6.1.0-beta.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_beta.major_minor_patch).to eq ["6", "1", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_beta.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_beta.semver_wildcard?).to be false
      end
    end

    context "when using a caret constraint" do
      let(:node_package_version_from_semver_caret) { node_package_version(fixture_version: "semver_caret") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_semver_caret.raw).to eq "6.5.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_semver_caret.major_minor_patch).to eq ["6", "5", "0"]
      end

      it "#skip_processing? false" do
        expect(node_package_version_from_semver_caret.skip_processing?).to be false
      end

      it "#semver_wildcard? false" do
        expect(node_package_version_from_semver_caret.semver_wildcard?).to be false
      end
    end

    context "when using a tilde constraint" do
      let(:node_package_version_from_semver_tilde) { node_package_version(fixture_version: "semver_tilde") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_semver_tilde.raw).to eq "6.0.2"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_semver_tilde.major_minor_patch).to eq ["6", "0", "2"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_semver_tilde.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_semver_tilde.semver_wildcard?).to be false
      end
    end

    context "when using a relative path" do
      let(:node_package_version_from_relative_path) { node_package_version(fixture_version: "relative_path") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_relative_path.raw).to eq "6.5.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_relative_path.major_minor_patch).to eq ["6", "5", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_relative_path.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_relative_path.semver_wildcard?).to be false
      end
    end

    context "when using a git url" do
      let(:node_package_version_from_git_url) { node_package_version(fixture_version: "git_url") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_git_url.raw).to eq "6.5.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_git_url.major_minor_patch).to eq ["6", "5", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_git_url.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_git_url.semver_wildcard?).to be false
      end
    end

    context "from GitHub url" do
      let(:node_package_version_from_github_url) { node_package_version(fixture_version: "github_url") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_github_url.raw).to eq "6.5.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_github_url.major_minor_patch).to eq ["6", "5", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_github_url.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_github_url.semver_wildcard?).to be false
      end
    end

    context "when shakapacker is not a dependency" do
      let(:node_package_version_from_without) { node_package_version(fixture_version: "without") }

      it "#raw returns an empty string" do
        expect(node_package_version_from_without.raw).to eq ""
      end

      it "#major_minor_patch returns nil" do
        expect(node_package_version_from_without.major_minor_patch).to be nil
      end

      it "#skip_processing? returns true" do
        expect(node_package_version_from_without.skip_processing?).to be  true
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_without.semver_wildcard?).to be false
      end
    end
  end

  context "with yarn.lock v2" do
    def node_package_version(fixture_version:)
      Shakapacker::VersionChecker::NodePackageVersion.new(
        File.expand_path("../fixtures/#{fixture_version}_package.json", __dir__),
        File.expand_path("../fixtures/#{fixture_version}_yarn.v2.lock", __dir__),
        "file/does/not/exist",
        "file/does/not/exist"
      )
    end

    context "when using an exact semantic version" do
      let(:node_package_version_from_semver_exact) { node_package_version(fixture_version: "semver_exact") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_semver_exact.raw).to eq "6.0.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_semver_exact.major_minor_patch).to eq ["6", "0", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_semver_exact.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_semver_exact.semver_wildcard?).to be false
      end
    end

    context "when using a beta version" do
      let(:node_package_version_from_beta) { node_package_version(fixture_version: "beta") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_beta.raw).to eq "6.1.0-beta.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_beta.major_minor_patch).to eq ["6", "1", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_beta.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_beta.semver_wildcard?).to be false
      end
    end

    context "when using a caret constraint" do
      let(:node_package_version_from_semver_caret) { node_package_version(fixture_version: "semver_caret") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_semver_caret.raw).to eq "6.5.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_semver_caret.major_minor_patch).to eq ["6", "5", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_semver_caret.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_semver_caret.semver_wildcard?).to be false
      end
    end

    context "when using a tilde constraint" do
      let(:node_package_version_from_semver_tilde) { node_package_version(fixture_version: "semver_tilde") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_semver_tilde.raw).to eq "6.0.2"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_semver_tilde.major_minor_patch).to eq ["6", "0", "2"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_semver_tilde.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_semver_tilde.semver_wildcard?).to be false
      end
    end

    context "when using a relative path" do
      let(:node_package_version_from_relative_path) { node_package_version(fixture_version: "relative_path") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_relative_path.raw).to eq "6.5.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_relative_path.major_minor_patch).to eq ["6", "5", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_relative_path.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_relative_path.semver_wildcard?).to be false
      end
    end

    context "when using a git url" do
      let(:node_package_version_from_git_url) { node_package_version(fixture_version: "git_url") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_git_url.raw).to eq "6.5.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_git_url.major_minor_patch).to eq ["6", "5", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_git_url.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_git_url.semver_wildcard?).to be false
      end
    end

    context "when using a github url" do
      let(:node_package_version_from_github_url) { node_package_version(fixture_version: "github_url") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_github_url.raw).to eq "6.5.0"
      end

      it "#major_minor_patch returns version array" do
        expect(node_package_version_from_github_url.major_minor_patch).to eq ["6", "5", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_github_url.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_github_url.semver_wildcard?).to be false
      end
    end

    context "when shakapacker is not a dependency" do
      let(:node_package_version_from_without) { node_package_version(fixture_version: "without") }

      it "#raw returns an empty string" do
        expect(node_package_version_from_without.raw).to eq ""
      end

      it "#major_minor_patch returns nil" do
        expect(node_package_version_from_without.major_minor_patch).to be nil
      end

      it "#skip_processing? returns true" do
        expect(node_package_version_from_without.skip_processing?).to be true
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_without.semver_wildcard?).to be false
      end
    end
  end

  context "with package-lock.json v1" do
    def node_package_version(fixture_version:)
      Shakapacker::VersionChecker::NodePackageVersion.new(
        File.expand_path("../fixtures/#{fixture_version}_package.json", __dir__),
        "file/does/not/exist",
        File.expand_path("../fixtures/#{fixture_version}_package-lock.v1.json", __dir__),
        "file/does/not/exist"
      )
    end

    context "when using an exact semantic version" do
      let(:node_package_version_from_semver_exact) { node_package_version(fixture_version: "semver_exact") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_semver_exact.raw).to eq "6.0.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_semver_exact.major_minor_patch).to eq ["6", "0", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_semver_exact.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_semver_exact.semver_wildcard?).to be false
      end
    end

    context "when using a beta version" do
      let(:node_package_version_from_beta) { node_package_version(fixture_version: "beta") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_beta.raw).to eq "6.1.0-beta.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_beta.major_minor_patch).to eq ["6", "1", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_beta.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_beta.semver_wildcard?).to be false
      end
    end

    context "when using a caret constraint" do
      let(:node_package_version_from_semver_caret) { node_package_version(fixture_version: "semver_caret") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_semver_caret.raw).to eq "6.5.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_semver_caret.major_minor_patch).to eq ["6", "5", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_semver_caret.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_semver_caret.semver_wildcard?).to be false
      end
    end

    context "when using a tilde constraint" do
      let(:node_package_version_from_semver_tilde) { node_package_version(fixture_version: "semver_tilde") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_semver_tilde.raw).to eq "6.0.2"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_semver_tilde.major_minor_patch).to eq ["6", "0", "2"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_semver_tilde.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_semver_tilde.semver_wildcard?).to be false
      end
    end

    context "when using a relative path" do
      let(:node_package_version_from_relative_path) { node_package_version(fixture_version: "relative_path") }

      it "#raw returns the relative path" do
        expect(node_package_version_from_relative_path.raw).to eq "file:../.."
      end

      it "#major_minor_patch returns nil" do
        expect(node_package_version_from_relative_path.major_minor_patch).to be nil
      end

      it "#skip_processing? returns true" do
        expect(node_package_version_from_relative_path.skip_processing?).to be true
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_relative_path.semver_wildcard?).to be false
      end
    end

    context "when using a git url" do
      let(:node_package_version_from_git_url) { node_package_version(fixture_version: "git_url") }

      it "#raw returns the git url" do
        expect(node_package_version_from_git_url.raw).to eq "git+ssh://git@github.com/shakacode/shakapacker.git#31854a58be49f736f3486a946b72d7e4f334e2b2"
      end

      it "#major_minor_patch returns nil" do
        expect(node_package_version_from_git_url.major_minor_patch).to be nil
      end

      it "#skip_processing? returns true" do
        expect(node_package_version_from_git_url.skip_processing?).to be true
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_git_url.semver_wildcard?).to be false
      end
    end

    context "when using a github url" do
      let(:node_package_version_from_github_url) { node_package_version(fixture_version: "github_url") }

      it "#raw returns the GitHub repo address" do
        expect(node_package_version_from_github_url.raw).to eq "github:shakacode/shakapacker#31854a58be49f736f3486a946b72d7e4f334e2b2"
      end

      it "#major_minor_patch returns nil" do
        expect(node_package_version_from_github_url.major_minor_patch).to be nil
      end

      it "#skip_processing? returns true" do
        expect(node_package_version_from_github_url.skip_processing?).to be true
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_github_url.semver_wildcard?).to be false
      end
    end

    context "when shakapacker is not a dependency" do
      let(:node_package_version_from_without) { node_package_version(fixture_version: "without") }

      it "#raw returns an empty string" do
        expect(node_package_version_from_without.raw).to eq ""
      end

      it "#major_minor_patch returns nil" do
        expect(node_package_version_from_without.major_minor_patch).to be nil
      end

      it "#skip_processing? returns true" do
        expect(node_package_version_from_without.skip_processing?).to be true
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_without.semver_wildcard?).to be false
      end
    end
  end

  context "with package-lock.json v2" do
    def node_package_version(fixture_version:)
      Shakapacker::VersionChecker::NodePackageVersion.new(
        File.expand_path("../fixtures/#{fixture_version}_package.json", __dir__),
        "file/does/not/exist",
        File.expand_path("../fixtures/#{fixture_version}_package-lock.v2.json", __dir__),
        "file/does/not/exist"
      )
    end

    context "when using an exact semantic version" do
      let(:node_package_version_from_semver_exact) { node_package_version(fixture_version: "semver_exact") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_semver_exact.raw).to eq "6.0.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_semver_exact.major_minor_patch).to eq ["6", "0", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_semver_exact.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_semver_exact.semver_wildcard?).to be false
      end
    end

    context "when using a beta version" do
      let(:node_package_version_from_beta) { node_package_version(fixture_version: "beta") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_beta.raw).to eq "6.1.0-beta.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_beta.major_minor_patch).to eq ["6", "1", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_beta.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_beta.semver_wildcard?).to be false
      end
    end

    context "when using a caret constraint" do
      let(:node_package_version_from_semver_caret) { node_package_version(fixture_version: "semver_caret") }

      it "#raw returns the raw version" do
        expect(node_package_version(fixture_version: "semver_caret").raw).to eq "6.5.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version(fixture_version: "semver_caret").major_minor_patch).to eq ["6", "5", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version(fixture_version: "semver_caret").skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version(fixture_version: "semver_caret").semver_wildcard?).to be false
      end
    end

    context "when using a tilde constraint" do
      let(:node_package_version_from_semver_tilde) { node_package_version(fixture_version: "semver_tilde") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_semver_tilde.raw).to eq "6.0.2"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_semver_tilde.major_minor_patch).to eq ["6", "0", "2"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_semver_tilde.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_semver_tilde.semver_wildcard?).to be false
      end
    end

    context "when using a relative path" do
      let(:node_package_version_from_relative_path) { node_package_version(fixture_version: "relative_path") }

      it "#raw returns the relative path" do
        expect(node_package_version_from_relative_path.raw).to eq "../.."
      end

      it "#major_minor_patch returns nil" do
        expect(node_package_version_from_relative_path.major_minor_patch).to be nil
      end

      it "#skip_processing? returns true" do
        expect(node_package_version_from_relative_path.skip_processing?).to be true
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_relative_path.semver_wildcard?).to be false
      end
    end

    context "when using a git url" do
      let(:node_package_version_from_git_url) { node_package_version(fixture_version: "git_url") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_git_url.raw).to eq "6.5.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_git_url.major_minor_patch).to eq ["6", "5", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_git_url.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_git_url.semver_wildcard?).to be false
      end
    end

    context "when using a github url" do
      let(:node_package_version_from_github_url) { node_package_version(fixture_version: "github_url") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_github_url.raw).to eq "6.5.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_github_url.major_minor_patch).to eq ["6", "5", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_github_url.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_github_url.semver_wildcard?).to be false
      end
    end

    context "when shakapacker is not a dependency" do
      let(:node_package_version_from_without) { node_package_version(fixture_version: "without") }

      it "#raw returns an empty string" do
        expect(node_package_version_from_without.raw).to eq ""
      end

      it "#major_minor_patch returns nil" do
        expect(node_package_version_from_without.major_minor_patch).to be nil
      end

      it "#skip_processing? returns true" do
        expect(node_package_version_from_without.skip_processing?).to be true
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_without.semver_wildcard?).to be false
      end
    end
  end

  context "with pnpm-lock.yaml v7" do
    def node_package_version(fixture_version:)
      Shakapacker::VersionChecker::NodePackageVersion.new(
        File.expand_path("../fixtures/#{fixture_version}_package.json", __dir__),
        "file/does/not/exist",
        "file/does/not/exist",
        File.expand_path("../fixtures/#{fixture_version}_pnpm-lock.v7.yaml", __dir__)
      )
    end

    context "when using an exact semantic version" do
      let(:node_package_version_from_semver_exact) { node_package_version(fixture_version: "semver_exact") }

      it "#raw returns version" do
        expect(node_package_version_from_semver_exact.raw).to eq "6.0.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_semver_exact.major_minor_patch).to eq ["6", "0", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_semver_exact.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_semver_exact.semver_wildcard?).to be false
      end
    end

    context "when using a beta version" do
      let(:node_package_version_from_beta) { node_package_version(fixture_version: "beta") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_beta.raw).to eq "6.1.0-beta.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_beta.major_minor_patch).to eq ["6", "1", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_beta.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_beta.semver_wildcard?).to be false
      end
    end

    context "when using a caret constraint" do
      let(:node_package_version_from_semver_caret) { node_package_version(fixture_version: "semver_caret") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_semver_caret.raw).to eq "6.6.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_semver_caret.major_minor_patch).to eq ["6", "6", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_semver_caret.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_semver_caret.semver_wildcard?).to be false
      end
    end

    context "when using a tilde constraint" do
      let(:node_package_version_from_semver_tilde) { node_package_version(fixture_version: "semver_tilde") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_semver_tilde.raw).to eq "6.0.2"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_semver_tilde.major_minor_patch).to eq ["6", "0", "2"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_semver_tilde.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_semver_tilde.semver_wildcard?).to be false
      end
    end

    context "when using a relative path" do
      let(:node_package_version_from_relative_path) { node_package_version(fixture_version: "relative_path") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_relative_path.raw).to eq "../.."
      end

      it "#major_minor_patch returns nil" do
        expect(node_package_version_from_relative_path.major_minor_patch).to be nil
      end

      it "#skip_processing? returns true" do
        expect(node_package_version_from_relative_path.skip_processing?).to be true
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_relative_path.semver_wildcard?).to be false
      end
    end

    context "when using a git url" do
      let(:node_package_version_from_git_url) { node_package_version(fixture_version: "git_url") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_git_url.raw).to eq "7.0.2"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_git_url.major_minor_patch).to eq ["7", "0", "2"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_git_url.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_git_url.semver_wildcard?).to be false
      end
    end

    context "when using a github url" do
      let(:node_package_version_from_github_url) { node_package_version(fixture_version: "github_url") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_github_url.raw).to eq "7.0.2"
      end

      it "#major_minor_patch returns version array" do
        expect(node_package_version_from_github_url.major_minor_patch).to eq ["7", "0", "2"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_github_url.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_github_url.semver_wildcard?).to be false
      end
    end

    context "when shakapacker is not a dependency" do
      let(:node_package_version_from_without) { node_package_version(fixture_version: "without") }

      it "#raw returns an empty string" do
        expect(node_package_version_from_without.raw).to eq ""
      end

      it "#major_minor_patch returns nil" do
        expect(node_package_version_from_without.major_minor_patch).to be nil
      end

      it "#skip_processing? returns true" do
        expect(node_package_version_from_without.skip_processing?).to be true
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_without.semver_wildcard?).to be false
      end
    end
  end

  context "with pnpm-lock.yaml v8" do
    def node_package_version(fixture_version:)
      Shakapacker::VersionChecker::NodePackageVersion.new(
        File.expand_path("../fixtures/#{fixture_version}_package.json", __dir__),
        "file/does/not/exist",
        "file/does/not/exist",
        File.expand_path("../fixtures/#{fixture_version}_pnpm-lock.v8.yaml", __dir__)
      )
    end

    context "when using an exact semantic version" do
      let(:node_package_version_from_semver_exact) { node_package_version(fixture_version: "semver_exact") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_semver_exact.raw).to eq "6.0.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_semver_exact.major_minor_patch).to eq ["6", "0", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_semver_exact.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_semver_exact.semver_wildcard?).to be false
      end
    end

    context "when using a beta version" do
      let(:node_package_version_from_beta) { node_package_version(fixture_version: "beta") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_beta.raw).to eq "6.1.0-beta.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_beta.major_minor_patch).to eq ["6", "1", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_beta.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_beta.semver_wildcard?).to be false
      end
    end

    context "when using a caret constraint" do
      let(:node_package_version_from_semver_caret) { node_package_version(fixture_version: "semver_caret") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_semver_caret.raw).to eq "6.0.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_semver_caret.major_minor_patch).to eq ["6", "0", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_semver_caret.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_semver_caret.semver_wildcard?).to be false
      end
    end

    context "when using a tilde constraint" do
      let(:node_package_version_from_semver_tilde) { node_package_version(fixture_version: "semver_tilde") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_semver_tilde.raw).to eq "6.0.0"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_semver_tilde.major_minor_patch).to eq ["6", "0", "0"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_semver_tilde.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_semver_tilde.semver_wildcard?).to be false
      end
    end

    context "when using a relative path" do
      let(:node_package_version_from_relative_path) { node_package_version(fixture_version: "relative_path") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_relative_path.raw).to eq "../.."
      end

      it "#major_minor_patch returns nil" do
        expect(node_package_version_from_relative_path.major_minor_patch).to be nil
      end

      it "#skip_processing? returns true" do
        expect(node_package_version_from_relative_path.skip_processing?).to be true
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_relative_path.semver_wildcard?).to be false
      end
    end

    context "when using a git url" do
      let(:node_package_version_from_git_url) { node_package_version(fixture_version: "git_url") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_git_url.raw).to eq "7.0.2"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_git_url.major_minor_patch).to eq ["7", "0", "2"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_git_url.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_git_url.semver_wildcard?).to be false
      end
    end

    context "when using a github url" do
      let(:node_package_version_from_github_url) { node_package_version(fixture_version: "github_url") }

      it "#raw returns the raw version" do
        expect(node_package_version_from_github_url.raw).to eq "7.0.2"
      end

      it "#major_minor_patch returns an array" do
        expect(node_package_version_from_github_url.major_minor_patch).to eq ["7", "0", "2"]
      end

      it "#skip_processing? returns false" do
        expect(node_package_version_from_github_url.skip_processing?).to be false
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_github_url.semver_wildcard?).to be false
      end
    end

    context "when shakapacker is not a dependency" do
      let(:node_package_version_from_without) { node_package_version(fixture_version: "without") }

      it "#raw returns an empty string" do
        expect(node_package_version_from_without.raw).to eq ""
      end

      it "#major_minor_patch returns nil" do
        expect(node_package_version_from_without.major_minor_patch).to be nil
      end

      it "#skip_processing? returns true" do
        expect(node_package_version_from_without.skip_processing?).to be true
      end

      it "#semver_wildcard? returns false" do
        expect(node_package_version_from_without.semver_wildcard?).to be false
      end
    end
  end
end

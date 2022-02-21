require "test_helper"
require "webpacker/version"

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

class VersionCheckerTest < Minitest::Test
  def check_version(node_package_version, stub_gem_version = Webpacker::VERSION, stub_config = true)
    version_checker = Webpacker::VersionChecker.new(node_package_version)
    version_checker.stub :gem_version, stub_gem_version do
      Webpacker.config.stub :ensure_consistent_versioning?, stub_config do
        version_checker.raise_if_gem_and_node_package_versions_differ
      end
    end
  end

  def test_message_printed_if_consistency_check_disabled_and_mismatch
    node_package_version = NodePackageVersionDouble.new(raw: "6.1.0", major_minor_patch: ["6", "1", "0"])

    out, err = capture_io do
      check_version(node_package_version, "6.0.0", false)
    end

    assert_match \
      "Webpacker::VersionChecker - Version mismatch detected",
      err
  end

  def test_message_printed_if_consistency_check_disabled_and_semver
    node_package_version = NodePackageVersionDouble.new(raw: "^6.1.0", major_minor_patch: ["6", "1", "0"], semver_wildcard: true)

    out, err = capture_io do
      check_version(node_package_version, "6.1.0", false)
    end

    assert_match \
      "Webpacker::VersionChecker - Semver wildcard detected",
      err
  end

  def test_raise_on_different_major_version
    node_package_version = NodePackageVersionDouble.new(raw: "6.1.0", major_minor_patch: ["6", "1", "0"])

    error = assert_raises do
      check_version(node_package_version, "7.0.0")
    end

    assert_match \
      "**ERROR** Webpacker: Webpacker gem and node package versions do not match",
      error.message
  end

  def test_raise_on_different_minor_version
    node_package_version = NodePackageVersionDouble.new(raw: "6.1.0", major_minor_patch: ["6", "1", "0"])

    error = assert_raises do
      check_version(node_package_version, "6.2.0")
    end

    assert_match \
      "**ERROR** Webpacker: Webpacker gem and node package versions do not match",
      error.message
  end

  def test_raise_on_different_patch_version
    node_package_version = NodePackageVersionDouble.new(raw: "6.1.1", major_minor_patch: ["6", "1", "1"])

    error = assert_raises do
      check_version(node_package_version, "6.1.2")
    end

    assert_match \
      "**ERROR** Webpacker: Webpacker gem and node package versions do not match",
      error.message
  end

  def test_raise_on_semver_wildcard
    node_package_version = NodePackageVersionDouble.new(raw: "^6.0.0", major_minor_patch: ["6", "0", "0"], semver_wildcard: true)

    error = assert_raises do
      check_version(node_package_version, "6.0.0")
    end

    assert_match \
      "**ERROR** Webpacker: Your node package version for shakapacker contains a ^ or ~",
      error.message
  end

  def test_no_raise_on_matching_versions
    node_package_version = NodePackageVersionDouble.new(raw: "6.0.0", major_minor_patch: ["6", "0", "0"])

    assert_silent do
      check_version(node_package_version, "6.0.0")
    end
  end

  def test_no_raise_on_matching_versions_beta
    node_package_version = NodePackageVersionDouble.new(raw: "6.0.0-beta.1", major_minor_patch: ["6", "0", "0"])

    assert_silent do
      check_version(node_package_version, "6.0.0.beta.1")
    end
  end

  def test_no_raise_on_no_package
    node_package_version = NodePackageVersionDouble.new(raw: nil, skip_processing: true)

    assert_silent do
      check_version(node_package_version, "6.0.0")
    end
  end

  def test_no_raise_on_skipped_path
    node_package_version = NodePackageVersionDouble.new(raw: "../shakapacker", skip_processing: true)

    assert_silent do
      check_version(node_package_version, "6.0.0")
    end
  end
end

class NodePackageVersionTest < Minitest::Test
  def node_package_version(fixture_version: "normal")
    file_path = File.expand_path("fixtures/#{fixture_version}_package.json", __dir__)
    Webpacker::VersionChecker::NodePackageVersion.new(file_path)
  end

  def test_normal_package_raw
    assert_equal "6.0.0", node_package_version.raw
  end

  def test_normal_package_major_minor_patch
    assert_equal ["6", "0", "0"], node_package_version.major_minor_patch
  end

  def test_normal_package_skip_processing
    assert_equal false, node_package_version.skip_processing?
  end

  def test_normal_package_semver_wildcard
    assert_equal false, node_package_version.semver_wildcard?
  end

  def test_beta_package_raw
    assert_equal "6.0.0-beta.1", node_package_version(fixture_version: "beta").raw
  end

  def test_beta_package_major_minor_patch
    assert_equal ["6", "0", "0"], node_package_version(fixture_version: "beta").major_minor_patch
  end

  def test_beta_package_skip_processing
    assert_equal false, node_package_version(fixture_version: "beta").skip_processing?
  end

  def test_beta_package_semver_wildcard
    assert_equal false, node_package_version(fixture_version: "beta").semver_wildcard?
  end

  def test_semver_caret_package_raw
    assert_equal "^6.0.0", node_package_version(fixture_version: "semver_caret").raw
  end

  def test_semver_caret_package_major_minor_patch
    assert_equal ["6", "0", "0"], node_package_version(fixture_version: "semver_caret").major_minor_patch
  end

  def test_semver_caret_package_skip_processing
    assert_equal false, node_package_version(fixture_version: "semver_caret").skip_processing?
  end

  def test_semver_caret_package_semver_wildcard
    assert_equal true, node_package_version(fixture_version: "semver_caret").semver_wildcard?
  end

  def test_semver_tilde_package_raw
    assert_equal "~6.0.0", node_package_version(fixture_version: "semver_tilde").raw
  end

  def test_semver_tilde_package_major_minor_patch
    assert_equal ["6", "0", "0"], node_package_version(fixture_version: "semver_tilde").major_minor_patch
  end

  def test_semver_tilde_package_skip_processing
    assert_equal false, node_package_version(fixture_version: "semver_tilde").skip_processing?
  end

  def test_semver_tilde_package_semver_wildcard
    assert_equal true, node_package_version(fixture_version: "semver_tilde").semver_wildcard?
  end

  def test_relative_path_package_raw
    assert_equal "../shakapacker", node_package_version(fixture_version: "relative_path").raw
  end

  def test_relative_path_package_major_minor_patch
    assert_nil node_package_version(fixture_version: "relative_path").major_minor_patch
  end

  def test_relative_path_package_skip_processing
    assert_equal true, node_package_version(fixture_version: "relative_path").skip_processing?
  end

  def test_relative_path_package_semver_wildcard
    assert_equal false, node_package_version(fixture_version: "relative_path").semver_wildcard?
  end

  def test_git_url_package_raw
    assert_equal "git://github.com/shakapacker/shakapacker.git", node_package_version(fixture_version: "git_url").raw
  end

  def test_git_url_package_major_minor_patch
    assert_nil node_package_version(fixture_version: "git_url").major_minor_patch
  end

  def test_git_url_package_skip_processing
    assert_equal true, node_package_version(fixture_version: "git_url").skip_processing?
  end

  def test_git_url_package_semver_wildcard
    assert_equal false, node_package_version(fixture_version: "git_url").semver_wildcard?
  end

  def test_github_url_package_raw
    assert_equal "shakapacker/shakapacker#feature/branch", node_package_version(fixture_version: "github_url").raw
  end

  def test_github_url_package_major_minor_patch
    assert_nil node_package_version(fixture_version: "github_url").major_minor_patch
  end

  def test_github_url_package_skip_processing
    assert_equal true, node_package_version(fixture_version: "github_url").skip_processing?
  end

  def test_github_url_package_semver_wildcard
    assert_equal false, node_package_version(fixture_version: "github_url").semver_wildcard?
  end

  def test_without_package_raw
    assert_equal "", node_package_version(fixture_version: "without").raw
  end

  def test_without_package_major_minor_patch
    assert_nil node_package_version(fixture_version: "without").major_minor_patch
  end

  def test_without_package_skip_processing
    assert_equal true, node_package_version(fixture_version: "without").skip_processing?
  end

  def test_without_package_semver_wildcard
    assert_equal false, node_package_version(fixture_version: "without").semver_wildcard?
  end
end

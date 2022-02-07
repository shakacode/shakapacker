require "test_helper"
require "webpacker/version"

class NodePackageVersionDouble
  attr_reader :raw, :major_minor_patch

  def initialize(raw: nil, major_minor_patch: nil, semver_wildcard: false, skip_processing: false, package_specified: true)
    @raw = raw
    @major_minor_patch = major_minor_patch
    @semver_wildcard = semver_wildcard
    @skip_processing = skip_processing
    @package_specified = package_specified
  end

  def semver_wildcard?
    @semver_wildcard
  end

  def skip_processing?
    @skip_processing
  end

  def package_specified?
    @package_specified
  end
end

class VersionCheckerTest < Minitest::Test
  def check_version(node_package_version, stub_gem_version = Webpacker::VERSION)
    version_checker = Webpacker::VersionChecker.new(node_package_version)
    version_checker.stub :gem_version, stub_gem_version do
      version_checker.raise_if_gem_and_node_package_versions_differ
    end
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
    node_package_version = NodePackageVersionDouble.new(raw: nil, package_specified: false)

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
end

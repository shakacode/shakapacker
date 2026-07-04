require "spec_helper"
require "shakapacker/doctor"

describe "binstub synchronization" do
  gem_root = File.expand_path("../..", __dir__)

  def helper_package_root_markers(path)
    content = File.read(path)
    marker_function = content.match(/def shakapacker_package_root_marker\?\(path\).*?%w\[\s*(.*?)\s*\]/m)
    expect(marker_function).not_to be_nil, "Could not find shakapacker_package_root_marker? marker list in #{path}"

    marker_function[1].split
  end

  # Binstubs that exist in both bin/ and lib/install/bin/ must stay identical,
  # except for the entries below which intentionally diverge.
  #
  # lib/install/bin/ contains the templates copied into user projects on install;
  # bin/ contains the versions used by Shakapacker's own repo and test apps.
  #
  # The shakapacker-config and diff-bundler-config helper binstubs diverge by
  # design (see PR #1104):
  #   - lib/install/bin/* are Ruby wrappers so Node does not parse them as ESM
  #     in apps with `"type": "module"` in package.json. They locate Node and
  #     exec the `.cjs` script at node_modules/shakapacker/package/bin/.
  #   - bin/* remain JS shims that rely on Node's package self-reference, which
  #     resolves inside Shakapacker's own repo where no node_modules/shakapacker
  #     exists. The configExporter integration test invokes bin/shakapacker-config
  #     via `node`, which requires the JS form.
  INTENTIONALLY_DIVERGENT_BINSTUBS = %w[shakapacker-config diff-bundler-config].freeze

  shared_binstubs = Dir.glob(File.join(gem_root, "lib/install/bin/*")).select do |install_path|
    name = File.basename(install_path)
    File.exist?(File.join(gem_root, "bin", name)) && !INTENTIONALLY_DIVERGENT_BINSTUBS.include?(name)
  end

  shared_binstubs.each do |install_path|
    name = File.basename(install_path)

    it "bin/#{name} matches lib/install/bin/#{name}" do
      bin_content = File.read(File.join(gem_root, "bin", name))
      install_content = File.read(install_path)
      expect(bin_content).to eq(install_content),
        "bin/#{name} and lib/install/bin/#{name} have diverged. " \
        "Update both files to keep them in sync."
    end
  end

  it "all documented divergent binstubs still exist in both directories" do
    install_basenames = Dir.glob(File.join(gem_root, "lib/install/bin/*")).map { |p| File.basename(p) }
    bin_basenames = Dir.glob(File.join(gem_root, "bin/*")).map { |p| File.basename(p) }
    actually_shared = install_basenames & bin_basenames

    documented_but_missing = INTENTIONALLY_DIVERGENT_BINSTUBS - actually_shared
    expect(documented_but_missing).to be_empty,
      "INTENTIONALLY_DIVERGENT_BINSTUBS lists #{documented_but_missing.inspect} " \
      "but those files are no longer present in both bin/ and lib/install/bin/. " \
      "Remove them from the list."
  end

  it "spec/dummy/bin/shakapacker-config matches lib/install/bin/shakapacker-config" do
    install_content = File.read(File.join(gem_root, "lib", "install", "bin", "shakapacker-config"))
    dummy_content = File.read(File.join(gem_root, "spec", "dummy", "bin", "shakapacker-config"))

    expect(dummy_content).to eq(install_content),
      "spec/dummy/bin/shakapacker-config and lib/install/bin/shakapacker-config have diverged. " \
      "All four copies must stay byte-for-byte identical — update each one: " \
      "lib/install/bin/shakapacker-config, lib/install/bin/diff-bundler-config, " \
      "spec/dummy/bin/shakapacker-config, and the createBinStub template in package/configExporter/cli.ts."
  end

  # lib/install/bin/diff-bundler-config and lib/install/bin/shakapacker-config share
  # the same helper functions and only legitimately diverge on the .cjs script name
  # they dispatch to. Normalizing that one line catches any other drift between them.
  it "lib/install/bin/diff-bundler-config stays in sync with lib/install/bin/shakapacker-config" do
    shakapacker_config = File.read(File.join(gem_root, "lib", "install", "bin", "shakapacker-config"))
    diff_bundler_config = File.read(File.join(gem_root, "lib", "install", "bin", "diff-bundler-config"))

    normalized = diff_bundler_config.sub('"diff-bundler-config.cjs"', '"shakapacker-config.cjs"')

    expect(normalized).to eq(shakapacker_config),
      "lib/install/bin/diff-bundler-config and lib/install/bin/shakapacker-config have diverged " \
      "beyond the intentional .cjs script name difference. Update both files to keep them in sync."
  end

  it "helper package-root markers stay aligned with Doctor" do
    helper_paths = [
      File.join(gem_root, "lib", "install", "bin", "shakapacker-config"),
      File.join(gem_root, "lib", "install", "bin", "diff-bundler-config"),
      File.join(gem_root, "spec", "dummy", "bin", "shakapacker-config"),
      File.join(gem_root, "package", "configExporter", "cli.ts")
    ]
    doctor_markers = Shakapacker::Doctor::PACKAGE_ROOT_MARKERS

    helper_paths.each do |path|
      expect(helper_package_root_markers(path)).to eq(doctor_markers),
        "#{path} package-root markers diverged from Shakapacker::Doctor::PACKAGE_ROOT_MARKERS"
    end
  end
end

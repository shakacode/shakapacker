require "spec_helper"

describe "binstub synchronization" do
  gem_root = File.expand_path("../..", __dir__)

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

  # The dummy app under spec/dummy/ ships a Ruby wrapper for shakapacker-config
  # so the dummy can exercise the binstub from a real `bin/` entry. It must
  # stay byte-identical to the install template, otherwise the dummy app would
  # silently exercise a stale wrapper and a change to the install template
  # could land without anyone noticing.
  it "spec/dummy/bin/shakapacker-config matches lib/install/bin/shakapacker-config" do
    dummy_path = File.join(gem_root, "spec/dummy/bin/shakapacker-config")
    install_path = File.join(gem_root, "lib/install/bin/shakapacker-config")
    expect(File.read(dummy_path)).to eq(File.read(install_path)),
      "spec/dummy/bin/shakapacker-config and lib/install/bin/shakapacker-config have diverged. " \
      "Update both files (and the createBinStub template in package/configExporter/cli.ts) to keep them in sync."
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
end

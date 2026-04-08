require "spec_helper"

describe "binstub synchronization" do
  gem_root = File.expand_path("../..", __dir__)

  # Binstubs that exist in both bin/ and lib/install/bin/ must stay identical.
  # lib/install/bin/ contains the templates copied into user projects on install;
  # bin/ contains the versions used by Shakapacker's own repo and test apps.
  shared_binstubs = Dir.glob(File.join(gem_root, "lib/install/bin/*")).select do |install_path|
    File.exist?(File.join(gem_root, "bin", File.basename(install_path)))
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
end

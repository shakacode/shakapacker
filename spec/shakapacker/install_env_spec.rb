require "spec_helper"
require "shakapacker/install/env"

describe Shakapacker::Install::Env do
  tracked_env_vars = %w[
    FORCE
    SKIP
    USE_BABEL_PACKAGES
    SHAKAPACKER_USE_TYPESCRIPT
    SKIP_COMMON_LOADERS
    SHAKAPACKER_ASSETS_BUNDLER
  ].freeze
  installer_flag_truthy_values = %w[true TRUE 1 yes YES].freeze
  installer_flag_falsey_values = ["false", "0", ""].freeze

  around do |example|
    original_values = tracked_env_vars.to_h { |name| [name, ENV[name]] }
    example.run
  ensure
    original_values.each do |name, value|
      value.nil? ? ENV.delete(name) : ENV[name] = value
    end
  end

  describe "truthy_env?" do
    it "recognizes 'true' as truthy" do
      ENV["FORCE"] = "true"
      expect(described_class.truthy_env?("FORCE")).to be true
    end

    it "recognizes 'TRUE' as truthy (case-insensitive)" do
      ENV["FORCE"] = "TRUE"
      expect(described_class.truthy_env?("FORCE")).to be true
    end

    it "recognizes '1' as truthy" do
      ENV["FORCE"] = "1"
      expect(described_class.truthy_env?("FORCE")).to be true
    end

    it "recognizes 'yes' as truthy" do
      ENV["FORCE"] = "yes"
      expect(described_class.truthy_env?("FORCE")).to be true
    end

    it "recognizes 'YES' as truthy (case-insensitive)" do
      ENV["FORCE"] = "YES"
      expect(described_class.truthy_env?("FORCE")).to be true
    end

    it "rejects 'false' as not truthy" do
      ENV["FORCE"] = "false"
      expect(described_class.truthy_env?("FORCE")).to be false
    end

    it "rejects '0' as not truthy" do
      ENV["FORCE"] = "0"
      expect(described_class.truthy_env?("FORCE")).to be false
    end

    it "rejects 'no' as not truthy" do
      ENV["FORCE"] = "no"
      expect(described_class.truthy_env?("FORCE")).to be false
    end

    it "rejects empty string as not truthy" do
      ENV["FORCE"] = ""
      expect(described_class.truthy_env?("FORCE")).to be false
    end

    it "rejects nil (unset) as not truthy" do
      ENV.delete("FORCE")
      expect(described_class.truthy_env?("FORCE")).to be false
    end
  end

  describe "truthy_env? for installer flags" do
    %w[USE_BABEL_PACKAGES SHAKAPACKER_USE_TYPESCRIPT SKIP_COMMON_LOADERS].each do |env_name|
      context "when checking #{env_name}" do
        it "accepts lower/upper truthy values" do
          installer_flag_truthy_values.each do |value|
            ENV[env_name] = value
            expect(described_class.truthy_env?(env_name)).to be true
          end
        end

        it "rejects falsey values and unset" do
          installer_flag_falsey_values.each do |value|
            ENV[env_name] = value
            expect(described_class.truthy_env?(env_name)).to be false
          end
          ENV.delete(env_name)
          expect(described_class.truthy_env?(env_name)).to be false
        end
      end
    end
  end

  describe "conflict_option" do
    it "returns force when FORCE=true" do
      ENV["FORCE"] = "true"
      ENV.delete("SKIP")
      expect(described_class.conflict_option).to eq({ force: true })
    end

    it "returns skip when SKIP=true" do
      ENV.delete("FORCE")
      ENV["SKIP"] = "true"
      expect(described_class.conflict_option).to eq({ skip: true })
    end

    it "returns empty hash when neither is set" do
      ENV.delete("FORCE")
      ENV.delete("SKIP")
      expect(described_class.conflict_option).to eq({})
    end

    it "returns empty hash when FORCE=false" do
      ENV["FORCE"] = "false"
      ENV.delete("SKIP")
      expect(described_class.conflict_option).to eq({})
    end

    it "returns empty hash when SKIP=0" do
      ENV.delete("FORCE")
      ENV["SKIP"] = "0"
      expect(described_class.conflict_option).to eq({})
    end

    it "returns empty hash when FORCE=false and SKIP=false" do
      ENV["FORCE"] = "false"
      ENV["SKIP"] = "false"
      expect(described_class.conflict_option).to eq({})
    end

    it "FORCE takes precedence over SKIP when both are truthy" do
      ENV["FORCE"] = "true"
      ENV["SKIP"] = "true"
      expect(described_class.conflict_option).to eq({ force: true })
    end

    it "falls through to SKIP when FORCE=false and SKIP=true" do
      ENV["FORCE"] = "false"
      ENV["SKIP"] = "true"
      expect(described_class.conflict_option).to eq({ skip: true })
    end
  end

  describe "update_transpiler_config?" do
    it "skips updates for default swc transpiler" do
      expect(
        described_class.update_transpiler_config?(
          transpiler_to_install: "swc",
          conflict_option: {},
          config_preexisting: false
        )
      ).to be false
    end

    it "skips updates for default swc transpiler even when FORCE=true" do
      expect(
        described_class.update_transpiler_config?(
          transpiler_to_install: "swc",
          conflict_option: { force: true },
          config_preexisting: true
        )
      ).to be false
    end

    it "updates config when transpiler is non-default and skip mode is off" do
      expect(
        described_class.update_transpiler_config?(
          transpiler_to_install: "babel",
          conflict_option: {},
          config_preexisting: true
        )
      ).to be true
    end

    it "updates config when FORCE=true even if config already exists" do
      expect(
        described_class.update_transpiler_config?(
          transpiler_to_install: "babel",
          conflict_option: { force: true },
          config_preexisting: true
        )
      ).to be true
    end

    it "updates config on fresh install even when SKIP=true" do
      expect(
        described_class.update_transpiler_config?(
          transpiler_to_install: "babel",
          conflict_option: { skip: true },
          config_preexisting: false
        )
      ).to be true
    end

    it "preserves existing user config when SKIP=true" do
      expect(
        described_class.update_transpiler_config?(
          transpiler_to_install: "babel",
          conflict_option: { skip: true },
          config_preexisting: true
        )
      ).to be false
    end
  end

  describe "update_assets_bundler_config?" do
    it "skips updates for the default webpack bundler" do
      expect(
        described_class.update_assets_bundler_config?(
          assets_bundler_to_install: "webpack",
          conflict_option: {},
          config_preexisting: false
        )
      ).to be false
    end

    it "skips updates for webpack regardless of FORCE (it is the template's shipped default)" do
      expect(
        described_class.update_assets_bundler_config?(
          assets_bundler_to_install: "webpack",
          conflict_option: { force: true },
          config_preexisting: true
        )
      ).to be false
    end

    it "updates config for a non-default bundler on a fresh install" do
      expect(
        described_class.update_assets_bundler_config?(
          assets_bundler_to_install: "rspack",
          conflict_option: {},
          config_preexisting: false
        )
      ).to be true
    end

    it "updates config for a non-default bundler when FORCE=true even if config already exists" do
      expect(
        described_class.update_assets_bundler_config?(
          assets_bundler_to_install: "rspack",
          conflict_option: { force: true },
          config_preexisting: true
        )
      ).to be true
    end

    it "updates config on fresh install even when SKIP=true" do
      expect(
        described_class.update_assets_bundler_config?(
          assets_bundler_to_install: "rspack",
          conflict_option: { skip: true },
          config_preexisting: false
        )
      ).to be true
    end

    it "preserves an existing user config when SKIP=true" do
      expect(
        described_class.update_assets_bundler_config?(
          assets_bundler_to_install: "rspack",
          conflict_option: { skip: true },
          config_preexisting: true
        )
      ).to be false
    end

    it "preserves an existing user config in interactive mode (no FORCE/SKIP)" do
      expect(
        described_class.update_assets_bundler_config?(
          assets_bundler_to_install: "rspack",
          conflict_option: {},
          config_preexisting: true
        )
      ).to be false
    end
  end

  describe "resolve_assets_bundler" do
    it "returns the env var value when set (it wins over force and existing config)" do
      expect(
        described_class.resolve_assets_bundler(env_value: "webpack", existing_bundler: "rspack", force: true)
      ).to eq "webpack"
    end

    it "returns the env var value verbatim so the caller can still reject a bad value" do
      expect(
        described_class.resolve_assets_bundler(env_value: "wbpack", existing_bundler: nil, force: false)
      ).to eq "wbpack"
    end

    it "treats an empty env var as set and returns it verbatim (the caller's VALID_BUNDLERS check then rejects it)" do
      expect(
        described_class.resolve_assets_bundler(env_value: "", existing_bundler: "webpack", force: false)
      ).to eq ""
    end

    it "installs the rspack default on FORCE, ignoring an existing bundler" do
      expect(
        described_class.resolve_assets_bundler(env_value: nil, existing_bundler: "webpack", force: true)
      ).to eq "rspack"
    end

    it "keeps an existing app's bundler when not overridden" do
      expect(
        described_class.resolve_assets_bundler(env_value: nil, existing_bundler: "webpack", force: false)
      ).to eq "webpack"
    end

    it "ignores an unrecognized existing value and falls back to rspack" do
      expect(
        described_class.resolve_assets_bundler(env_value: nil, existing_bundler: "wbpack", force: false)
      ).to eq "rspack"
    end

    it "defaults a brand-new install (no env, no existing config) to rspack" do
      expect(
        described_class.resolve_assets_bundler(env_value: nil, existing_bundler: nil, force: false)
      ).to eq "rspack"
    end
  end

  describe "apply_bundler_arg" do
    before { ENV.delete("SHAKAPACKER_ASSETS_BUNDLER") }

    it "sets SHAKAPACKER_ASSETS_BUNDLER and returns no error for webpack" do
      expect(described_class.apply_bundler_arg("webpack")).to be_nil
      expect(ENV["SHAKAPACKER_ASSETS_BUNDLER"]).to eq "webpack"
    end

    it "sets SHAKAPACKER_ASSETS_BUNDLER and returns no error for rspack" do
      expect(described_class.apply_bundler_arg("rspack")).to be_nil
      expect(ENV["SHAKAPACKER_ASSETS_BUNDLER"]).to eq "rspack"
    end

    it "lets an explicit argument override an existing SHAKAPACKER_ASSETS_BUNDLER" do
      ENV["SHAKAPACKER_ASSETS_BUNDLER"] = "rspack"
      expect(described_class.apply_bundler_arg("webpack")).to be_nil
      expect(ENV["SHAKAPACKER_ASSETS_BUNDLER"]).to eq "webpack"
    end

    it "returns an error and leaves SHAKAPACKER_ASSETS_BUNDLER unset for an unknown bundler" do
      error = described_class.apply_bundler_arg("wbpack")

      expect(error).to include "Unknown bundler 'wbpack'"
      expect(error).to include "webpack, rspack"
      expect(ENV).not_to have_key("SHAKAPACKER_ASSETS_BUNDLER")
    end

    it "matches strictly, rejecting values that differ only by case or surrounding whitespace" do
      expect(described_class.apply_bundler_arg("Rspack")).to include "Unknown bundler 'Rspack'"
      expect(described_class.apply_bundler_arg(" rspack")).to include "Unknown bundler ' rspack'"
      expect(ENV).not_to have_key("SHAKAPACKER_ASSETS_BUNDLER")
    end

    it "does nothing when no bundler argument is given" do
      expect(described_class.apply_bundler_arg(nil)).to be_nil
      expect(described_class.apply_bundler_arg("")).to be_nil
      expect(ENV).not_to have_key("SHAKAPACKER_ASSETS_BUNDLER")
    end
  end
end

require "spec_helper"
require "shakapacker/install/env"

describe Shakapacker::Install::Env do
  around do |example|
    original_force = ENV["FORCE"]
    original_skip = ENV["SKIP"]
    example.run
  ensure
    original_force.nil? ? ENV.delete("FORCE") : ENV["FORCE"] = original_force
    original_skip.nil? ? ENV.delete("SKIP") : ENV["SKIP"] = original_skip
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

    it "updates config when transpiler is non-default and skip mode is off" do
      expect(
        described_class.update_transpiler_config?(
          transpiler_to_install: "babel",
          conflict_option: {},
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
end

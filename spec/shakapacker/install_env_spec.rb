require "spec_helper"

describe "Installer environment variable handling" do
  # Mirrors the truthy_env? helper defined in lib/install/template.rb
  def truthy_env?(name)
    %w[true 1 yes].include?(ENV[name].to_s.downcase)
  end

  def conflict_option
    if truthy_env?("FORCE")
      { force: true }
    elsif truthy_env?("SKIP")
      { skip: true }
    else
      {}
    end
  end

  around do |example|
    original_force = ENV["FORCE"]
    original_skip = ENV["SKIP"]
    example.run
  ensure
    ENV["FORCE"] = original_force
    ENV["SKIP"] = original_skip
  end

  describe "truthy_env?" do
    it "recognizes 'true' as truthy" do
      ENV["FORCE"] = "true"
      expect(truthy_env?("FORCE")).to be true
    end

    it "recognizes 'TRUE' as truthy (case-insensitive)" do
      ENV["FORCE"] = "TRUE"
      expect(truthy_env?("FORCE")).to be true
    end

    it "recognizes '1' as truthy" do
      ENV["FORCE"] = "1"
      expect(truthy_env?("FORCE")).to be true
    end

    it "recognizes 'yes' as truthy" do
      ENV["FORCE"] = "yes"
      expect(truthy_env?("FORCE")).to be true
    end

    it "recognizes 'YES' as truthy (case-insensitive)" do
      ENV["FORCE"] = "YES"
      expect(truthy_env?("FORCE")).to be true
    end

    it "rejects 'false' as not truthy" do
      ENV["FORCE"] = "false"
      expect(truthy_env?("FORCE")).to be false
    end

    it "rejects '0' as not truthy" do
      ENV["FORCE"] = "0"
      expect(truthy_env?("FORCE")).to be false
    end

    it "rejects 'no' as not truthy" do
      ENV["FORCE"] = "no"
      expect(truthy_env?("FORCE")).to be false
    end

    it "rejects empty string as not truthy" do
      ENV["FORCE"] = ""
      expect(truthy_env?("FORCE")).to be false
    end

    it "rejects nil (unset) as not truthy" do
      ENV.delete("FORCE")
      expect(truthy_env?("FORCE")).to be false
    end
  end

  describe "conflict_option" do
    it "returns force when FORCE=true" do
      ENV["FORCE"] = "true"
      ENV.delete("SKIP")
      expect(conflict_option).to eq({ force: true })
    end

    it "returns skip when SKIP=true" do
      ENV.delete("FORCE")
      ENV["SKIP"] = "true"
      expect(conflict_option).to eq({ skip: true })
    end

    it "returns empty hash when neither is set" do
      ENV.delete("FORCE")
      ENV.delete("SKIP")
      expect(conflict_option).to eq({})
    end

    it "returns empty hash when FORCE=false" do
      ENV["FORCE"] = "false"
      ENV.delete("SKIP")
      expect(conflict_option).to eq({})
    end

    it "returns empty hash when SKIP=0" do
      ENV.delete("FORCE")
      ENV["SKIP"] = "0"
      expect(conflict_option).to eq({})
    end

    it "returns empty hash when FORCE=false and SKIP=false" do
      ENV["FORCE"] = "false"
      ENV["SKIP"] = "false"
      expect(conflict_option).to eq({})
    end

    it "FORCE takes precedence over SKIP when both are truthy" do
      ENV["FORCE"] = "true"
      ENV["SKIP"] = "true"
      expect(conflict_option).to eq({ force: true })
    end

    it "falls through to SKIP when FORCE=false and SKIP=true" do
      ENV["FORCE"] = "false"
      ENV["SKIP"] = "true"
      expect(conflict_option).to eq({ skip: true })
    end
  end
end

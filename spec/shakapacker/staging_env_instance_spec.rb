require "spec_helper"
require "shakapacker"

describe "Shakapacker::Instance with staging environment" do
  context "when Rails is not defined" do
    it "should not raise uninitialized constant error when accessed outside Rails context" do
      # Simulate the scenario where Rails is not loaded (as in bin/shakapacker)
      if defined?(Rails)
        stub_const("Rails", nil)
      end

      # This simulates what happens in the runner when a staging env doesn't have config
      expect {
        Shakapacker::Instance.new(
          root_path: Pathname.new(Dir.pwd),
          config_path: Pathname.new(File.join(Dir.pwd, "config/shakapacker.yml"))
        )
      }.not_to raise_error
    end
  end

  context "when using Runner with staging environment" do
    let(:config_path) { File.join(Dir.pwd, "spec/fixtures/staging_config.yml") }

    before do
      # Create a minimal config file for testing with distinct values
      FileUtils.mkdir_p(File.dirname(config_path))
      File.write(config_path, <<~YAML)
        development:
          source_path: app/javascript
          source_entry_path: packs
          compile: true
        production:
          source_path: app/packs
          source_entry_path: entrypoints
          compile: false
      YAML
    end

    after do
      FileUtils.rm_f(config_path)
    end

    it "should handle staging environment without Rails being loaded" do
      # This simulates what happens when RAILS_ENV=staging is set
      # and the config doesn't have a staging section
      config = Shakapacker::Configuration.new(
        root_path: Pathname.new(Dir.pwd),
        config_path: Pathname.new(config_path),
        env: "staging"
      )

      # Should fall back to production config values
      expect(config.compile?).to eq(false)
      expect(config.source_path.to_s).to end_with("app/packs")
      expect(config.source_entry_path.to_s).to end_with("entrypoints")
    end
  end
end

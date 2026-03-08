require "spec_helper"
require "shakapacker"

describe "Shakapacker::Env without Rails" do
  let(:config_path) { Pathname.new(File.join(Dir.pwd, "spec/fixtures/env_test_config.yml")) }

  before do
    FileUtils.mkdir_p(config_path.dirname)
    File.write(config_path, <<~YAML)
      development:
        source_path: app/javascript
      production:
        source_path: app/packs
      test:
        source_path: app/javascript
    YAML
  end

  after do
    FileUtils.rm_f(config_path)
  end

  context "when Rails is not defined" do
    let(:instance) do
      Shakapacker::Instance.new(
        root_path: Pathname.new(Dir.pwd),
        config_path: config_path
      )
    end

    before do
      stub_const("Rails", nil) if defined?(Rails)
    end

    it "falls back to RAILS_ENV environment variable" do
      stub_const("ENV", ENV.to_h.merge("RAILS_ENV" => "development", "RACK_ENV" => nil))
      env = Shakapacker::Env.inquire(instance)
      expect(env).to eq "development"
    end

    it "falls back to RACK_ENV when RAILS_ENV is not set" do
      stub_const("ENV", ENV.to_h.merge("RAILS_ENV" => nil, "RACK_ENV" => "production"))
      env = Shakapacker::Env.inquire(instance)
      expect(env).to eq "production"
    end

    it "falls back to production when no env is available" do
      stub_const("ENV", ENV.to_h.merge("RAILS_ENV" => nil, "RACK_ENV" => nil))
      env = Shakapacker::Env.inquire(instance)
      expect(env).to eq "production"
    end

    it "does not raise NameError" do
      stub_const("ENV", ENV.to_h.merge("RAILS_ENV" => nil, "RACK_ENV" => nil))
      expect { Shakapacker::Env.inquire(instance) }.not_to raise_error
    end
  end
end

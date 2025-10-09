require_relative "spec_helper_initializer"

describe "Shakapacker" do
  describe "#inline_css?" do
    let(:dev_server) { instance_double("Shakapacker::DevServer") }

    before :each do
      allow(dev_server).to receive(:host).and_return("localhost")
      allow(dev_server).to receive(:port).and_return("3035")
      allow(dev_server).to receive(:pretty?).and_return(false)
      allow(dev_server).to receive(:running?).and_return(true)
    end

    it "returns nil when the dev server is disabled" do
      expect(Shakapacker.inlining_css?).to be nil
    end

    it "returns true when hmr is enabled" do
      allow(dev_server).to receive(:hmr?).and_return(true)
      allow(dev_server).to receive(:inline_css?).and_return(true)

      allow(Shakapacker.instance).to receive(:dev_server).and_return(dev_server)

      expect(Shakapacker.inlining_css?).to be true
    end

    it "returns false when hmr is enabled and inline_css is explicitly set to false" do
      allow(dev_server).to receive(:hmr?).and_return(true)
      allow(dev_server).to receive(:inline_css?).and_return(false)

      allow(Shakapacker.instance).to receive(:dev_server).and_return(dev_server)

      expect(Shakapacker.inlining_css?).to be false
    end
  end

  it "automatically cleans up app_autoload_paths" do
    expect($test_app_autoload_paths_in_initializer).to eq []
  end

  describe "#ensure_node_env!" do
    after do
      # Clean up ENV after each test
      ENV.delete("NODE_ENV")
      ENV.delete("RAILS_ENV")
    end

    it "sets NODE_ENV to development when RAILS_ENV is development" do
      ENV["RAILS_ENV"] = "development"
      ENV.delete("NODE_ENV")

      Shakapacker.ensure_node_env!

      expect(ENV["NODE_ENV"]).to eq("development")
    end

    it "sets NODE_ENV to test when RAILS_ENV is test" do
      ENV["RAILS_ENV"] = "test"
      ENV.delete("NODE_ENV")

      Shakapacker.ensure_node_env!

      expect(ENV["NODE_ENV"]).to eq("test")
    end

    it "sets NODE_ENV to production when RAILS_ENV is staging" do
      ENV["RAILS_ENV"] = "staging"
      ENV.delete("NODE_ENV")

      Shakapacker.ensure_node_env!

      expect(ENV["NODE_ENV"]).to eq("production")
    end

    it "sets NODE_ENV to production when RAILS_ENV is production" do
      ENV["RAILS_ENV"] = "production"
      ENV.delete("NODE_ENV")

      Shakapacker.ensure_node_env!

      expect(ENV["NODE_ENV"]).to eq("production")
    end

    it "sets NODE_ENV to production when RAILS_ENV is any other custom environment" do
      ENV["RAILS_ENV"] = "custom_env"
      ENV.delete("NODE_ENV")

      Shakapacker.ensure_node_env!

      expect(ENV["NODE_ENV"]).to eq("production")
    end

    it "does not override existing NODE_ENV" do
      ENV["RAILS_ENV"] = "staging"
      ENV["NODE_ENV"] = "development"

      Shakapacker.ensure_node_env!

      expect(ENV["NODE_ENV"]).to eq("development")
    end

    it "handles nil RAILS_ENV by defaulting to production" do
      ENV.delete("RAILS_ENV")
      ENV.delete("NODE_ENV")

      Shakapacker.ensure_node_env!

      expect(ENV["NODE_ENV"]).to eq("production")
    end
  end
end

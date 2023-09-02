require_relative "spec_helper_initializer"

describe "DevServer" do
  it "doesn't run by default" do
    expect(Webpacker.dev_server.running?).to be_falsy
  end

  it "uses localhost as host in development environment" do
    with_rails_env("development") do
      expect(Webpacker.dev_server.host).to eq "localhost"
    end
  end

  it "uses port 3035 in development environment" do
    with_rails_env("development") do
      expect(Webpacker.dev_server.port).to eq 3035
    end
  end

  it "doesn't use https in development environment" do
    with_rails_env("development") do
      expect(Webpacker.dev_server.https?).to be false
    end
  end

  it "uses http protocol in development environment" do
    with_rails_env("development") do
      expect(Webpacker.dev_server.protocol).to eq "http"
    end
  end

  it "sets host_with_port to localhost:3035 in development environment" do
    with_rails_env("development") do
      expect(Webpacker.dev_server.host_with_port).to eq "localhost:3035"
    end
  end

  it "doesn't use pretty in development environment" do
    with_rails_env("development") do
      expect(Webpacker.dev_server.pretty?).to be false
    end
  end

  it "uses SHAKAPACKER_DEV_SERVER for DEFAULT_ENV_PREFIX" do
    expect(Webpacker::DevServer::DEFAULT_ENV_PREFIX).to eq "SHAKAPACKER_DEV_SERVER"
  end
end

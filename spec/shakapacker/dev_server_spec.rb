require_relative "spec_helper_initializer"

describe "DevServer" do
  it "doesn't run by default" do
    expect(Shakapacker.dev_server.running?).to be_falsy
  end

  it "doesn't run when the connected socket reports an error" do
    socket = instance_double(Socket)
    socket_error = instance_double(Socket::Option, int: Errno::ECONNREFUSED::Errno)

    allow(Socket).to receive(:tcp).and_return(socket)
    allow(socket).to receive(:getsockopt)
      .with(Socket::SOL_SOCKET, Socket::SO_ERROR)
      .and_return(socket_error)
    allow(socket).to receive(:close)

    with_rails_env("development") do
      expect(Shakapacker.dev_server.running?).to be false
    end

    expect(socket).to have_received(:close)
  end

  it "runs when the connected socket reports no error" do
    socket = instance_double(Socket)
    socket_error = instance_double(Socket::Option, int: 0)

    allow(Socket).to receive(:tcp).and_return(socket)
    allow(socket).to receive(:getsockopt)
      .with(Socket::SOL_SOCKET, Socket::SO_ERROR)
      .and_return(socket_error)
    allow(socket).to receive(:close)

    with_rails_env("development") do
      expect(Shakapacker.dev_server.running?).to be true
    end

    expect(socket).to have_received(:close)
  end

  it "uses localhost as host in development environment" do
    with_rails_env("development") do
      expect(Shakapacker.dev_server.host).to eq "localhost"
    end
  end

  it "uses port 3035 in development environment" do
    with_rails_env("development") do
      expect(Shakapacker.dev_server.port).to eq 3035
    end
  end

  it "uses http protocol in development environment" do
    with_rails_env("development") do
      expect(Shakapacker.dev_server.protocol).to eq "http"
    end
  end

  it "sets host_with_port to localhost:3035 in development environment" do
    with_rails_env("development") do
      expect(Shakapacker.dev_server.host_with_port).to eq "localhost:3035"
    end
  end

  it "doesn't use pretty in development environment" do
    with_rails_env("development") do
      expect(Shakapacker.dev_server.pretty?).to be false
    end
  end

  it "uses SHAKAPACKER_DEV_SERVER for DEFAULT_ENV_PREFIX" do
    expect(Shakapacker::DevServer::DEFAULT_ENV_PREFIX).to eq "SHAKAPACKER_DEV_SERVER"
  end

  context "#protocol in development environment" do
    let(:dev_server) { Shakapacker.dev_server }

    it "returns `http` by default (with unset `server`)" do
      with_rails_env("development") do
        expect(dev_server.protocol).to eq "http"
      end
    end

    it "returns `https` when `server` is set to `https`" do
      expect(dev_server).to receive(:server).and_return("https")

      with_rails_env("development") do
        expect(dev_server.protocol).to eq "https"
      end
    end
  end

  context "#server in development environment" do
    let(:dev_server) { Shakapacker.dev_server }

    it "returns `http` when unset" do
      expect(dev_server).to receive(:fetch).with(:server).and_return(nil)

      with_rails_env("development") do
        expect(dev_server.server).to eq "http"
      end
    end

    it "returns `http` when set to `https`" do
      expect(dev_server).to receive(:fetch).with(:server).and_return("http")

      with_rails_env("development") do
        expect(dev_server.server).to eq "http"
      end
    end

    it "returns `http` when set to a hash with `type: http`" do
      expect(dev_server).to receive(:fetch).with(:server).and_return({
        type: "http",
        options: {}
      })

      with_rails_env("development") do
        expect(dev_server.server).to eq "http"
      end
    end

    it "returns `https` when set to `https`" do
      expect(dev_server).to receive(:fetch).with(:server).and_return("https")

      with_rails_env("development") do
        expect(dev_server.server).to eq "https"
      end
    end

    it "returns `https` when set to a hash with `type: https`" do
      expect(dev_server).to receive(:fetch).with(:server).and_return({
        type: "https",
        options: {}
      })

      with_rails_env("development") do
        expect(dev_server.server).to eq "https"
      end
    end

    it "returns `http` when set to any value except `http` and `https`" do
      expect(dev_server).to receive(:fetch).twice.with(:server).and_return("other-than-https")

      with_rails_env("development") do
        expect(dev_server.server).to eq "http"
        expect { dev_server.server }.to output(/WARNING/).to_stdout
      end
    end
  end
end

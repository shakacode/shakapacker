require_relative "spec_helper_initializer"

require "socket"
require "shakapacker/dev_server_proxy"

describe "Shakapacker::DevServerProxy" do
  PACK_RESPONSE_BODY = "console.log('hi');".freeze

  def with_dev_server_listening
    server = TCPServer.new("127.0.0.1", 0)

    thread = Thread.new do
      socket = server.accept
      loop do
        line = socket.gets
        break if line.nil? || line == "\r\n"
      end
      socket.write(
        "HTTP/1.1 200 OK\r\n" \
        "Content-Type: application/javascript\r\n" \
        "Content-Length: #{PACK_RESPONSE_BODY.bytesize}\r\n" \
        "\r\n#{PACK_RESPONSE_BODY}"
      )
      socket.close
    rescue IOError, Errno::EBADF, Errno::ECONNRESET
      nil
    end

    yield server.addr[1]
  ensure
    thread&.kill
    server&.close
  end

  def rack_env(path)
    Rack::MockRequest.env_for("https://example.com#{path}")
  end

  # The streaming body responds to #each but is not Enumerable.
  def read_body(response)
    body = response[2]
    buffer = +""
    body.each { |chunk| buffer << chunk }
    buffer
  ensure
    body.close if body.respond_to?(:close)
  end

  let(:app) { ->(_env) { [204, {}, []] } }
  let(:proxy) { Shakapacker::DevServerProxy.new(app) }

  around do |example|
    with_rails_env("development") { example.run }
  end

  context "when the dev server is running" do
    around do |example|
      with_dev_server_listening do |port|
        @port = port
        example.run
      end
    end

    before do
      dev_server = Shakapacker.dev_server
      allow(dev_server).to receive(:running?).and_return(true)
      allow(dev_server).to receive(:host).and_return("127.0.0.1")
      allow(dev_server).to receive(:port).and_return(@port)
      allow(dev_server).to receive(:host_with_port).and_return("127.0.0.1:#{@port}")
    end

    it "proxies a request for a pack to the dev server" do
      response = proxy.call(rack_env("/packs/application.js"))

      expect(response[0]).to eq 200
      expect(read_body(response)).to eq PACK_RESPONSE_BODY
    end

    it "passes a request outside the output path to the app" do
      expect(proxy.call(rack_env("/home"))[0]).to eq 204
    end
  end

  it "passes a request for a pack to the app when the dev server is not running" do
    allow(Shakapacker.dev_server).to receive(:running?).and_return(false)

    expect(proxy.call(rack_env("/packs/application.js"))[0]).to eq 204
  end
end

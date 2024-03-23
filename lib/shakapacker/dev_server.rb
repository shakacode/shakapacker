class Shakapacker::DevServer
  DEFAULT_ENV_PREFIX = "SHAKAPACKER_DEV_SERVER".freeze

  # Configure dev server connection timeout (in seconds), default: 0.1
  # Shakapacker.dev_server.connect_timeout = 1
  cattr_accessor(:connect_timeout) { 0.1 }

  attr_reader :config

  def initialize(config)
    @config = config
  end

  def running?
    if config.dev_server.present?
      Socket.tcp(host, port, connect_timeout: connect_timeout).close
      true
    else
      false
    end
  rescue
    false
  end

  def host
    fetch(:host)
  end

  def port
    fetch(:port)
  end

  def server
    server_value = fetch(:server)
    server_type = server_value.is_a?(Hash) ? server_value[:type] : server_value

    return server_type if ["http", "https"].include?(server_type)

    return "http" if server_type.nil?

    puts <<~MSG
    WARNING:
    `server: #{server_type}` is not a valid configuration in Shakapacker.
    Falling back to default `server: http`.
    MSG

    "http"
  rescue KeyError
    "http"
  end

  def protocol
    return "https" if server == "https"

    "http"
  end

  def host_with_port
    "#{host}:#{port}"
  end

  def pretty?
    fetch(:pretty)
  end

  def hmr?
    fetch(:hmr)
  end

  def inline_css?
    case fetch(:inline_css)
    when false, "false"
      false
    else
      true
    end
  end

  def env_prefix
    config.dev_server.fetch(:env_prefix, DEFAULT_ENV_PREFIX)
  end

  private
    def fetch(key)
      return nil unless config.dev_server.present?

      ENV["#{env_prefix}_#{key.upcase}"] || config.dev_server.fetch(key, defaults[key])
    rescue
      nil
    end

    def defaults
      config.send(:defaults)[:dev_server] || {}
    end
end

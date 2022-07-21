class Webpacker::Env
  delegate :config_path, :logger, to: :@webpacker

  def self.inquire(webpacker)
    new(webpacker).inquire
  end

  def initialize(webpacker)
    @webpacker = webpacker
  end

  def inquire
    fallback_env_warning if config_path.exist? && !current
    current || Webpacker::DEFAULT_ENV.inquiry
  end

  private
    def current
      Rails.env.presence_in(available_environments)
    end

    def fallback_env_warning
      logger.info "RAILS_ENV=#{Rails.env} environment is not defined in config/webpacker.yml, falling back to #{Webpacker::DEFAULT_ENV} environment"
    end

    def available_environments
      if config_path.exist?
        begin
          YAML.load_file(config_path.to_s, aliases: true)
        rescue ArgumentError
          YAML.load_file(config_path.to_s)
        end
      else
        [].freeze
      end
    rescue Psych::SyntaxError => e
      raise "YAML syntax error occurred while parsing #{config_path}. " \
            "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
            "Error: #{e.message}"
    end
end

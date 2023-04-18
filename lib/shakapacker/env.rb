class Shakapacker::Env
  delegate :custom_config, :logger, to: :@instance

  def self.inquire(instance)
    new(instance).inquire
  end

  def initialize(instance)
    @instance = instance
  end

  def inquire
    fallback_env_warning if !current
    current || Shakapacker::DEFAULT_ENV.inquiry
  end

  private
    def current
      Rails.env.presence_in(available_environments)
    end

    def fallback_env_warning
      logger.info "RAILS_ENV=#{Rails.env} environment is not defined in config/shakapacker.yml, falling back to #{Shakapacker::DEFAULT_ENV} environment"
    end

    def available_environments
      custom_config.keys.map(&:to_s)
    end
end

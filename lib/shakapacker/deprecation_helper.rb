module Shakapacker
  DEPRECATION_GUIDE_URL = "https://github.com/shakacode/shakapacker/docs/v7_upgrade.md"
  DEPRECATION_MESSAGE = <<~MSG
    \e[33m
    DEPRECATION NOTICE:

    Using Webpacker module is deprecated in Shakapacker. Thought this version
    offers backward compatibility, it is strongly recommended to update your
    project to comply with the new interfaces.

    For more information about this process, check:
    #{DEPRECATION_GUIDE_URL}
    \e[0m
  MSG

  class << self
    # For backward compatibility
    def get_config_file_path_with_backward_compatibility(config_path)
      if config_path.to_s.end_with?("shakapacker.yml") && !File.exist?(config_path)
        webpacker_config_path = if config_path.class == Pathname
          Pathname.new(config_path.to_s.gsub("shakapacker.yml", "webpacker.yml"))
        else
          config_path.gsub("shakapacker.yml", "webpacker.yml")
        end

        if File.exist?(webpacker_config_path)
          puts <<~MSG

          DEPRECATION NOTICE:
          Using `config/webpacker.yml` is deprecated. Consider using `config/shakapacker.yml`.

          MSG
          return webpacker_config_path
        end
      end

      config_path
    end
  end

  def set_shakapacker_env_variables_for_backward_compatibility
    webpacker_env_variables = ENV.select { |key| key.start_with?("WEBPACKER_") }
    webpacker_env_variables.each do |webpacker_key, _|
      shakapacker_key = webpacker_key.gsub("WEBPACKER_", "SHAKAPACKER_")
      next if ENV.key?(shakapacker_key)

      puts <<~MSG
        \e[33m
        DEPRECATION NOTICE:
        Use `#{shakapacker_key}` instead of deprecated `#{webpacker_key}`.
        Read more: #{Shakapacker::DEPRECATION_GUIDE_URL}
        \e[0m
      MSG
      ENV[shakapacker_key] = ENV[webpacker_key]
    end
  end
end

module Shakapacker
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
end

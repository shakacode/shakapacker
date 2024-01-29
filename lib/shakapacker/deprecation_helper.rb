require "thor"

module Shakapacker
  DEPRECATION_GUIDE_URL = "https://github.com/shakacode/shakapacker/blob/main/docs/v7_upgrade.md"
  DEPRECATION_MESSAGE = <<~MSG
    DEPRECATION NOTICE:

    Using webpacker spelling is deprecated in Shakapacker.
    Update your project with the new spelling.

    For more information about this process, check:
    #{DEPRECATION_GUIDE_URL}
  MSG
  SHELL = Thor::Shell::Color.new

  def get_config_file_path_with_backward_compatibility(config_path)
    if config_path.to_s.end_with?("shakapacker.yml") && !File.exist?(config_path)
      webpacker_config_path = if config_path.class == Pathname
        Pathname.new(config_path.to_s.gsub("shakapacker.yml", "webpacker.yml"))
      else
        config_path.gsub("shakapacker.yml", "webpacker.yml")
      end

      if File.exist?(webpacker_config_path)
        puts_deprecation_message(
          short_deprecation_message(
            "config/webpacker.yml",
            "config/shakapacker.yml"
          )
        )
        return webpacker_config_path
      end
    end

    config_path
  end

  def set_shakapacker_env_variables_for_backward_compatibility
    webpacker_env_variables = ENV.select { |key| key.start_with?("WEBPACKER_") }

    deprecation_message_body = ""

    webpacker_env_variables.each do |webpacker_key, _|
      shakapacker_key = webpacker_key.gsub("WEBPACKER_", "SHAKAPACKER_")
      next if ENV.key?(shakapacker_key)

      deprecation_message_body += <<~MSG
        Use `#{shakapacker_key}` instead of the deprecated `#{webpacker_key}`.
      MSG

      ENV[shakapacker_key] = ENV[webpacker_key]
    end

    if deprecation_message_body.present?
      Shakapacker.puts_deprecation_message(
        <<~MSG
          DEPRECATION NOTICE:

          #{deprecation_message_body}
          Read more: #{Shakapacker::DEPRECATION_GUIDE_URL}
        MSG
      )
    end
  end

  def short_deprecation_message(old_usage, new_usage)
    <<~MSG
      DEPRECATION NOTICE:

      Consider using `#{new_usage}` instead of the deprecated `#{old_usage}`.
      Read more: #{DEPRECATION_GUIDE_URL}
    MSG
  end

  def puts_deprecation_message(message)
    SHELL.say "\n#{message}\n", :yellow
  end

  def puts_rake_deprecation_message(webpacker_task_name)
    Shakapacker.puts_deprecation_message(
      Shakapacker.short_deprecation_message(
        "rake #{webpacker_task_name}",
        "rake #{webpacker_task_name.gsub("webpacker", "shakapacker")}"
      )
    )
  end
end

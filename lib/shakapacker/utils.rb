require "yaml"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/hash/indifferent_access"
require_relative "deprecation_helper"

module Shakapacker
  module Utils
    class << self
      def parse_config_file_to_hash(config_path = Rails.root.join("config/shakapacker.yml"))
        # For backward compatibility
        config_path = Shakapacker.get_config_file_path_with_backward_compatibility(config_path)

        raise Errno::ENOENT unless File.exist?(config_path)

        config = begin
          YAML.load_file(config_path.to_s, aliases: true)
        rescue ArgumentError
          YAML.load_file(config_path.to_s)
        end.deep_symbolize_keys

        # For backward compatibility
        config.each do |env, config_for_env|
          if config_for_env.key?(:shakapacker_precompile) && !config_for_env.key?(:webpacker_precompile)
            config[env][:webpacker_precompile] = config[env][:shakapacker_precompile]
          elsif !config_for_env.key?(:shakapacker_precompile) && config_for_env.key?(:webpacker_precompile)
            config[env][:shakapacker_precompile] = config[env][:webpacker_precompile]
          end
        end

        return config
      rescue Errno::ENOENT => e
        # TODO: Can we check installing status in a better way?
        if ENV["SHAKAPACKER_INSTALLING"] == true
          {}
        else
          raise "Shakapacker configuration file not found #{config_path}. " \
                "Please run rails shakapacker:install " \
                "Error: #{e.message}"
        end
      rescue Psych::SyntaxError => e
        raise "YAML syntax error occurred while parsing #{config_path}. " \
              "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
              "Error: #{e.message}"
      end
    end
  end
end

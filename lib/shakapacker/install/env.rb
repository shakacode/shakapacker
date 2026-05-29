module Shakapacker
  module Install
    module Env
      TRUTHY_VALUES = %w[true 1 yes].freeze

      module_function

      def truthy_env?(name)
        TRUTHY_VALUES.include?(ENV[name].to_s.downcase)
      end

      def conflict_option
        if truthy_env?("FORCE")
          { force: true }
        elsif truthy_env?("SKIP")
          { skip: true }
        else
          {}
        end
      end

      # Preserve existing shakapacker.yml when SKIP mode is active, but still
      # update newly-copied files on fresh installs.
      def update_transpiler_config?(transpiler_to_install:, conflict_option:, config_preexisting:)
        return false if transpiler_to_install == "swc"
        return true if conflict_option[:force]
        return true unless conflict_option[:skip]

        !config_preexisting
      end

      # Keep bundled runtime defaults backward compatible while allowing the
      # installer to write an explicit new-project bundler choice. Only rewrite
      # when copy_file actually wrote the bundled template (config_written); a
      # preserved user config (SKIP mode or a declined overwrite) is left as-is.
      def update_assets_bundler_config?(assets_bundler_to_install:, config_written:)
        # The bundled shakapacker.yml already ships assets_bundler: "webpack", so
        # rewriting it to "webpack" would be a no-op. This relies on that shipped default.
        return false if assets_bundler_to_install == "webpack"

        config_written
      end
    end
  end
end

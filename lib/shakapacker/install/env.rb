module Shakapacker
  module Install
    module Env
      TRUTHY_VALUES = %w[true 1 yes].freeze
      VALID_BUNDLERS = %w[webpack rspack].freeze

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
      # installer to write an explicit new-project bundler choice. Takes the same
      # inputs as update_transpiler_config? for consistency, but is deliberately
      # more conservative: switching an existing app's bundler is impactful, so we
      # only rewrite a config the installer owns (a fresh install, or an explicit
      # FORCE overwrite) and never a pre-existing one (interactive or SKIP mode).
      def update_assets_bundler_config?(assets_bundler_to_install:, conflict_option:, config_preexisting:)
        # The bundled shakapacker.yml already ships assets_bundler: "webpack", so
        # rewriting it to "webpack" would be a no-op. This relies on that shipped default.
        return false if assets_bundler_to_install == "webpack"
        return true if conflict_option[:force]

        !config_preexisting
      end

      # Apply an optional `shakapacker:install[bundler]` task argument. A
      # recognized bundler (webpack or rspack) is written to
      # SHAKAPACKER_ASSETS_BUNDLER so the install template picks it up; an
      # unrecognized value is ignored — the bundler then falls back to the env
      # var or the rspack default — and described in the returned warning so the
      # caller can surface it. Returns nil when no argument was given or there is
      # nothing to warn about.
      def apply_bundler_arg(bundler_arg)
        return nil if bundler_arg.nil? || bundler_arg.empty?

        if VALID_BUNDLERS.include?(bundler_arg)
          ENV["SHAKAPACKER_ASSETS_BUNDLER"] = bundler_arg
          nil
        else
          "Unknown bundler '#{bundler_arg}'; ignoring it. Valid values: #{VALID_BUNDLERS.join(", ")}."
        end
      end
    end
  end
end

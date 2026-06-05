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

      # Resolve which bundler the installer should set up. Precedence: an explicit
      # SHAKAPACKER_ASSETS_BUNDLER env var (or task argument, which sets that env var)
      # always wins; otherwise a FORCE overwrite installs the new-project default;
      # otherwise an existing app keeps its current bundler (when it is a recognized
      # value) so a re-install never silently switches it; brand-new installs fall
      # back to rspack. Returning the env var verbatim lets the caller's strict
      # VALID_BUNDLERS check still reject a misspelled value.
      def resolve_assets_bundler(env_value:, existing_bundler:, force:)
        return env_value if env_value
        return "rspack" if force
        return existing_bundler if VALID_BUNDLERS.include?(existing_bundler)

        "rspack"
      end

      # Apply an optional `shakapacker:install[bundler]` task argument. A
      # recognized bundler (webpack or rspack) is written to
      # SHAKAPACKER_ASSETS_BUNDLER so the install template picks it up,
      # overriding any value already set in that env var (the explicit argument
      # wins). An unrecognized value returns an error message (and leaves the
      # env var unset) so the caller can abort, mirroring the template's strict
      # validation of SHAKAPACKER_ASSETS_BUNDLER. Returns nil when the argument
      # is valid or absent.
      def apply_bundler_arg(bundler_arg)
        return nil if bundler_arg.nil? || bundler_arg.empty?

        if VALID_BUNDLERS.include?(bundler_arg)
          ENV["SHAKAPACKER_ASSETS_BUNDLER"] = bundler_arg
          nil
        else
          "Unknown bundler '#{bundler_arg}'. Valid values: #{VALID_BUNDLERS.join(", ")}."
        end
      end
    end
  end
end

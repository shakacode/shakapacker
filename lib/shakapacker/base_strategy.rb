module Shakapacker
  class BaseStrategy
    def initialize(instance)
      @instance = instance
    end

    def after_compile_hook
      nil
    end

    private

      def config
        @instance.config
      end

      def env
        @instance.env
      end

      def default_watched_paths
        [
          *config.additional_paths.map { |path| "#{path}{,/**/*}" },
          "#{config.source_path}{,/**/*}",
          "package.json", "package-lock.json", "yarn.lock",
          "pnpm-lock.yaml", "bun.lockb",
          "config/{webpack,rspack}{,/**/*}"
        ].freeze
      end
  end
end

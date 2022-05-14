module Webpacker
  class BaseStrategy
    def initialize
      @config = Webpacker.config
    end

    def after_compile_hook
      nil
    end

    private

      attr_reader :config

      def default_watched_paths
        [
          *config.additional_paths.map { |path| "#{path}{,/**/*}" },
          "#{config.source_path}{,/**/*}",
          "yarn.lock", "package.json",
          "config/webpack{,/**/*}"
        ].freeze
      end
  end
end

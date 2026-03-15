require_relative "mtime_strategy"
require_relative "digest_strategy"

module Shakapacker
  class CompilerStrategy
    def self.from_config(instance)
      strategy_from_config = instance.config.compiler_strategy

      case strategy_from_config
      when "mtime"
        Shakapacker::MtimeStrategy.new(instance)
      when "digest"
        Shakapacker::DigestStrategy.new(instance)
      else
        raise "Unknown strategy '#{strategy_from_config}'. " \
              "Available options are 'mtime' and 'digest'."
      end
    end
  end
end

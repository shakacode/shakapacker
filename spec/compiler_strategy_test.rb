require "test_helper"

class CompilerStrategyTest < Minitest::Test
  def test_mtime_strategy_returned
    Webpacker.config.stub :compiler_strategy, "mtime" do
      assert_instance_of Webpacker::MtimeStrategy, Webpacker::CompilerStrategy.from_config
    end
  end

  def test_digest_strategy_returned
    Webpacker.config.stub :compiler_strategy, "digest" do
      assert_instance_of Webpacker::DigestStrategy, Webpacker::CompilerStrategy.from_config
    end
  end

  def test_raise_on_unknown_strategy
    Webpacker.config.stub :compiler_strategy, "other" do
      error = assert_raises do
        Webpacker::CompilerStrategy.from_config
      end

      assert_equal \
        "Unknown strategy 'other'. Available options are 'mtime' and 'digest'.",
        error.message
    end
  end
end

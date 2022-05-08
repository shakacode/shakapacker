require "test_helper"

class DigestStrategyTest < Minitest::Test
  def remove_compilation_digest_path
    @digest_strategy.send(:compilation_digest_path).tap do |path|
      path.delete if path.exist?
    end
  end

  def setup
    @digest_strategy = Webpacker::DigestStrategy.new
    remove_compilation_digest_path
  end

  def teardown
    remove_compilation_digest_path
  end

  def test_compilation_digest_path
    assert_equal @digest_strategy.send(:compilation_digest_path).basename.to_s, "last-compilation-digest-#{Webpacker.env}"
  end
end
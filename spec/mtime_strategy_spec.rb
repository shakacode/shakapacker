require "test_helper"

class MtimeStrategyTest < Minitest::Test
  def setup
    @mtime_strategy = Webpacker::MtimeStrategy.new
    @manifest_timestamp = Time.parse("2021-01-01 12:34:56 UTC")
  end

  def with_stubs(latest_timestamp:, manifest_exists: true)
    @mtime_strategy.stub :latest_modified_timestamp, latest_timestamp do
      FileTest.stub :exist?, manifest_exists do
        File.stub :mtime, @manifest_timestamp do
          yield
        end
      end
    end
  end

  def test_freshness_when_manifest_missing
    latest_timestamp = @manifest_timestamp + 3600

    with_stubs(latest_timestamp: latest_timestamp.to_i, manifest_exists: false) do
      assert @mtime_strategy.stale?
    end
  end

  def test_freshness_when_manifest_older
    latest_timestamp = @manifest_timestamp + 3600

    with_stubs(latest_timestamp: latest_timestamp.to_i) do
      assert @mtime_strategy.stale?
    end
  end

  def test_freshness_when_manifest_newer
    latest_timestamp = @manifest_timestamp - 3600

    with_stubs(latest_timestamp: latest_timestamp.to_i) do
      assert @mtime_strategy.fresh?
    end
  end
end

require "test_helper"

class CompilerTest < Minitest::Test
  def test_custom_environment_variables
    assert_nil Webpacker.compiler.send(:webpack_env)["FOO"]
    Webpacker.compiler.env["FOO"] = "BAR"
    assert Webpacker.compiler.send(:webpack_env)["FOO"] == "BAR"
  ensure
    Webpacker.compiler.env = {}
  end

  def setup
    @manifest_timestamp = Time.parse("2021-01-01 12:34:56 UTC")
  end

  def with_stubs(latest_timestamp:, manifest_exists: true, &proc)
    @latest_timestamp = latest_timestamp

    Webpacker.compiler.stub :latest_modified_timestamp, @latest_timestamp do
      FileTest.stub :exist?, manifest_exists do
        File.stub :mtime, @manifest_timestamp do
          yield proc
        end
      end
    end
  end

  def test_freshness_when_manifest_missing
    latest_timestamp = @manifest_timestamp + 3600

    with_stubs(latest_timestamp: latest_timestamp.to_i, manifest_exists: false) do
      assert Webpacker.compiler.stale?
    end
  end

  def test_freshness_when_manifest_older
    latest_timestamp = @manifest_timestamp + 3600

    with_stubs(latest_timestamp: latest_timestamp.to_i) do
      assert Webpacker.compiler.stale?
    end
  end

  def test_freshness_when_manifest_newer
    latest_timestamp = @manifest_timestamp - 3600

    with_stubs(latest_timestamp: latest_timestamp.to_i) do
      assert Webpacker.compiler.fresh?
    end
  end

  def test_compile
    assert !Webpacker.compiler.compile
  end

  def test_external_env_variables
    assert_nil Webpacker.compiler.send(:webpack_env)["WEBPACKER_ASSET_HOST"]
    assert_nil Webpacker.compiler.send(:webpack_env)["WEBPACKER_RELATIVE_URL_ROOT"]

    ENV["WEBPACKER_ASSET_HOST"] = "foo.bar"
    ENV["WEBPACKER_RELATIVE_URL_ROOT"] = "/baz"
    assert_equal Webpacker.compiler.send(:webpack_env)["WEBPACKER_ASSET_HOST"], "foo.bar"
    assert_equal Webpacker.compiler.send(:webpack_env)["WEBPACKER_RELATIVE_URL_ROOT"], "/baz"
  end
end

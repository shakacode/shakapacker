require "test_helper"

class CompilerTest < Minitest::Test
  def test_custom_environment_variables
    assert_nil Webpacker.compiler.send(:webpack_env)["FOO"]
    Webpacker.compiler.env["FOO"] = "BAR"
    assert Webpacker.compiler.send(:webpack_env)["FOO"] == "BAR"
  ensure
    Webpacker.compiler.env = {}
  end

  def test_compile_true_when_fresh
    mock = Minitest::Mock.new
    mock.expect(:stale?, false)
    Webpacker.compiler.stub(:strategy, mock) do
      assert Webpacker.compiler.compile
    end
    assert_mock mock
  end

  def test_after_compile_hook_called_on_success
    mock = Minitest::Mock.new
    mock.expect(:stale?, true)
    mock.expect(:after_compile_hook, nil)

    status = OpenStruct.new(success?: true)

    Webpacker.compiler.stub(:strategy, mock) do
      Open3.stub :capture3, [:sterr, :stdout, status] do
        Webpacker.compiler.compile
      end
    end
    assert_mock mock
  end

  def test_after_compile_hook_called_on_failure
    mock = Minitest::Mock.new
    mock.expect(:stale?, true)
    mock.expect(:after_compile_hook, nil)

    status = OpenStruct.new(success?: false)

    Webpacker.compiler.stub(:strategy, mock) do
      Open3.stub :capture3, [:sterr, :stdout, status] do
        Webpacker.compiler.compile
      end
    end
    assert_mock mock
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

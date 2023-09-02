require_relative "spec_helper_initializer"

describe "RakeTasks" do
  TEST_APP_PATH = File.expand_path("webpacker_test_app", __dir__)

  it "`rake -T` lists Webpacker tasks" do
    output = Dir.chdir(TEST_APP_PATH) { `rake -T` }

    expect(output).to match /webpacker .+DEPRECATED/
    expect(output).to match /webpacker:check_binstubs.+DEPRECATED/
    expect(output).to match /webpacker:check_node.+DEPRECATED/
    expect(output).to match /webpacker:check_yarn.+DEPRECATED/
    expect(output).to match /webpacker:clean.+DEPRECATED/
    expect(output).to match /webpacker:clobber.+DEPRECATED/
    expect(output).to match /webpacker:compile.+DEPRECATED/
    expect(output).to match /webpacker:install.+DEPRECATED/
    expect(output).to match /webpacker:verify_install.+DEPRECATED/
  end

  it "`webpacker:check_binstubs` doesn't get 'webpack binstub not found' error" do
    output = Dir.chdir(TEST_APP_PATH) { `rake webpacker:check_binstubs 2>&1` }

    expect(output).to_not include "webpack binstub not found."
    expect(output).to include "DEPRECATION"
  end

  it "`webpacker:check_node` doesn't get 'webpacker requires Node.js' error" do
    output = Dir.chdir(TEST_APP_PATH) { `rake webpacker:check_node 2>&1` }

    expect(output).to_not include "Shakapacker requires Node.js"
    expect(output).to include "DEPRECATION"
  end

  it "`webpacker:check_yarn` doesn't get error related to yarn" do
    output = Dir.chdir(TEST_APP_PATH) { `rake webpacker:check_yarn 2>&1` }

    expect(output).to_not include "Yarn not installed"
    expect(output).to_not include "Shakapacker requires Yarn"
    expect(output).to include "DEPRECATION"
  end
end

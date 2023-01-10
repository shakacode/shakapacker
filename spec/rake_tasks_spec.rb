describe "RakeTasks" do
  let(:test_app_path) { File.expand_path("test_app", __dir__) }

  it "`rake -T` lists webpacker tasks" do
    output = Dir.chdir(test_app_path) { `rake -T` }
    expect(output).to include "webpacker"
    expect(output).to include "webpacker:check_binstubs"
    expect(output).to include "webpacker:check_node"
    expect(output).to include "webpacker:check_yarn"
    expect(output).to include "webpacker:clean"
    expect(output).to include "webpacker:clobber"
    expect(output).to include "webpacker:compile"
    expect(output).to include "webpacker:install"
    expect(output).to include "webpacker:verify_install"
  end

  it "`webpacker:check_binstubs` doesn't get 'webpack binstub not found' error" do
    output = Dir.chdir(test_app_path) { `rake webpacker:check_binstubs 2>&1` }
    expect(output).to_not include "webpack binstub not found."
  end

  it "`webpacker:check_node` doesn't get 'Webpacker requires Node.js' error" do
    output = Dir.chdir(test_app_path) { `rake webpacker:check_node 2>&1` }
    expect(output).to_not include "Webpacker requires Node.js"
  end

  it "`webpacker:check_yarn` doesn't get error related to yarn" do
    output = Dir.chdir(test_app_path) { `rake webpacker:check_yarn 2>&1` }
    expect(output).to_not include "Yarn not installed"
    expect(output).to_not include "Webpacker requires Yarn"
  end
end

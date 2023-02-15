describe "RakeTasks" do
  let(:test_app_path) { File.expand_path("test_app", __dir__) }

  it "`rake -T` lists Shakapacker tasks" do
    output = Dir.chdir(test_app_path) { `rake -T` }
    expect(output).to include "shakapacker"
    expect(output).to include "shakapacker:check_binstubs"
    expect(output).to include "shakapacker:check_node"
    expect(output).to include "shakapacker:check_yarn"
    expect(output).to include "shakapacker:clean"
    expect(output).to include "shakapacker:clobber"
    expect(output).to include "shakapacker:compile"
    expect(output).to include "shakapacker:install"
    expect(output).to include "shakapacker:verify_install"
  end

  it "`shakapacker:check_binstubs` doesn't get 'webpack binstub not found' error" do
    output = Dir.chdir(test_app_path) { `rake shakapacker:check_binstubs 2>&1` }
    expect(output).to_not include "webpack binstub not found."
  end

  it "`shakapacker:check_node` doesn't get 'shakapacker requires Node.js' error" do
    output = Dir.chdir(test_app_path) { `rake shakapacker:check_node 2>&1` }
    expect(output).to_not include "Shakapacker requires Node.js"
  end

  it "`shakapacker:check_yarn` doesn't get error related to yarn" do
    output = Dir.chdir(test_app_path) { `rake shakapacker:check_yarn 2>&1` }
    expect(output).to_not include "Yarn not installed"
    expect(output).to_not include "Shakapacker requires Yarn"
  end
end

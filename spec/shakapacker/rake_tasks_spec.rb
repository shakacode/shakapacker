require_relative "spec_helper_initializer"

describe "RakeTasks" do
  TEST_APP_PATH = File.expand_path("../test_app", __dir__)

  it "`rake -T` lists Shakapacker tasks" do
    output = Dir.chdir(TEST_APP_PATH) { `rake -T` }
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
    output = Dir.chdir(TEST_APP_PATH) { `rake shakapacker:check_binstubs 2>&1` }
    expect(output).to_not include "webpack binstub not found."
  end

  it "`shakapacker:check_node` doesn't get 'shakapacker requires Node.js' error" do
    output = Dir.chdir(TEST_APP_PATH) { `rake shakapacker:check_node 2>&1` }
    expect(output).to_not include "Shakapacker requires Node.js"
  end

  it "`shakapacker:check_yarn` doesn't get error related to yarn" do
    output = Dir.chdir(TEST_APP_PATH) { `rake shakapacker:check_yarn 2>&1` }
    expect(output).to_not include "Yarn not installed"
    expect(output).to_not include "Shakapacker requires Yarn"
  end

  describe "`shakapacker:check_binstubs`" do
    before :all do
      Dir.chdir(TEST_APP_PATH)
    end

    context "with existing `./bin/shapapacker` and `./bin/shapapacker-dev-server`" do
      it "passes" do
        expect { system("bundle exec rake shakapacker:check_binstubs") }.to output("").to_stdout_from_any_process
      end
    end

    context "without `./bin/shakapacker`" do
      before :all do
        FileUtils.mv("bin/shakapacker", "bin/shakapacker_renamed")
      end

      after :all do
        FileUtils.mv("bin/shakapacker_renamed", "bin/shakapacker")
      end

      it "passes if `./bin/webpacker exist" do
        with_temporary_file("bin/webpacker") do
          expect { system("bundle exec rake shakapacker:check_binstubs") }.to output(/DEPRECATION/).to_stdout_from_any_process
        end
      end

      it "fails otherwise" do
        expect { system("bundle exec rake shakapacker:check_binstubs") }.to output(/Couldn't find shakapacker binstubs!/).to_stdout_from_any_process
      end
    end

    context "without `./bin/shakapacker-dev-server`" do
      before :all do
        FileUtils.mv("bin/shakapacker-dev-server", "bin/shakapacker-dev-server_renamed")
      end

      after :all do
        FileUtils.mv("bin/shakapacker-dev-server_renamed", "bin/shakapacker-dev-server")
      end

      it "passes if `./bin/webpacker-dev-server exist" do
        with_temporary_file("bin/webpacker-dev-server") do
          expect { system("bundle exec rake shakapacker:check_binstubs") }.to output(/DEPRECATION/).to_stdout_from_any_process
        end
      end

      it "fails otherwise" do
        expect { system("bundle exec rake shakapacker:check_binstubs") }.to output(/Couldn't find shakapacker binstubs!/).to_stdout_from_any_process
      end
    end
  end
end

def with_temporary_file(file_name, &block)
  FileUtils.touch(file_name, verbose: false)
  yield if block_given?
ensure
  FileUtils.rm_f(file_name, verbose: false)
end

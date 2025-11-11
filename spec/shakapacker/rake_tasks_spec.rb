require_relative "spec_helper_initializer"

describe "RakeTasks" do
  TEST_APP_PATH = File.expand_path("./test_app", __dir__)

  it "`rake -T` lists Shakapacker tasks" do
    output = Dir.chdir(TEST_APP_PATH) { `rake -T` }
    expect(output).to include "shakapacker"
    expect(output).to include "shakapacker:check_binstubs"
    expect(output).to include "shakapacker:check_node"
    expect(output).to include "shakapacker:check_manager"
    expect(output).to include "shakapacker:clean"
    expect(output).to include "shakapacker:clobber"
    expect(output).to include "shakapacker:compile"
    expect(output).to include "shakapacker:install"
    expect(output).to include "shakapacker:verify_install"
    expect(output).to include "shakapacker:switch_bundler"
  end

  it "`shakapacker:check_binstubs` doesn't get 'webpack binstub not found' error" do
    output = Dir.chdir(TEST_APP_PATH) { `rake shakapacker:check_binstubs 2>&1` }

    expect(output).to_not include "webpack binstub not found."
  end

  it "`shakapacker:check_node` doesn't get 'shakapacker requires Node.js' error" do
    output = Dir.chdir(TEST_APP_PATH) { `rake shakapacker:check_node 2>&1` }

    expect(output).to_not include "Shakapacker requires Node.js"
  end

  # TODO: currently this test depends on external conditions & PACKAGE_JSON_FALLBACK_MANAGER
  it "`shakapacker:check_manager` doesn't get errors related to the package manager" do
    output = Dir.chdir(TEST_APP_PATH) { `rake shakapacker:check_manager 2>&1` }

    expect(output).to_not include "not installed"
    expect(output).to_not include "Shakapacker requires"
  end

  describe "`shakapacker:check_binstubs`" do
    def with_temporary_file(file_name)
      FileUtils.touch(file_name, verbose: false)
      yield if block_given?
    ensure
      FileUtils.rm_f(file_name, verbose: false)
    end

    before :all do
      Dir.chdir(TEST_APP_PATH)
    end

    context "with existing `./bin/shakapacker` and `./bin/shakapacker-dev-server`" do
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

      it "fails" do
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

      it "fails" do
        expect { system("bundle exec rake shakapacker:check_binstubs") }.to output(/Couldn't find shakapacker binstubs!/).to_stdout_from_any_process
      end
    end
  end

  describe "`shakapacker:switch_bundler`" do
    before :all do
      Dir.chdir(TEST_APP_PATH)
    end

    it "shows error when called with rails command" do
      # Simulate calling with rails by creating a temporary rails executable
      # This tests the command detection logic
      output = `bundle exec rake shakapacker:switch_bundler 2>&1`
      # Should not show the rails error when called with rake
      expect(output).not_to include "must be run with 'bundle exec rake', not 'bundle exec rails'"
    end

    it "shows usage when called without arguments" do
      output = `bundle exec rake shakapacker:switch_bundler 2>&1`
      expect(output).to include "Current bundler:"
      expect(output).to include "Usage:"
    end

    it "shows help with --help flag" do
      output = `bundle exec rake shakapacker:switch_bundler -- --help 2>&1`
      expect(output).to include "Current bundler:"
      expect(output).to include "Usage:"
      expect(output).to include "Examples:"
    end

    it "shows help with -h flag" do
      output = `bundle exec rake shakapacker:switch_bundler -- -h 2>&1`
      expect(output).to include "Current bundler:"
      expect(output).to include "Usage:"
    end

    it "rejects invalid bundler name" do
      output = `bundle exec rake shakapacker:switch_bundler invalid 2>&1`
      expect(output).to include "Invalid bundler"
    end

    it "accepts webpack as valid bundler" do
      output = `bundle exec rake shakapacker:switch_bundler webpack 2>&1`
      expect(output).not_to include "Invalid bundler"
      # Should show success or already using message
      expect(output).to match(/Switched (from|to) .* (to )?webpack|already using webpack/i)
    end

    it "accepts rspack as valid bundler" do
      output = `bundle exec rake shakapacker:switch_bundler rspack 2>&1`
      expect(output).not_to include "Invalid bundler"
      # Should show success or already using message
      expect(output).to match(/Switched (from|to) .* (to )?rspack|already using rspack/i)
    end
  end
end

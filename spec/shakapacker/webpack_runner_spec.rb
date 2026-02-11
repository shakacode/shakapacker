require_relative "spec_helper_initializer"
require_relative "shared/help_and_version_examples"
require "shakapacker/webpack_runner"

describe "WebpackRunner" do
  around do |example|
    within_temp_directory do
      FileUtils.cp_r(File.expand_path("./test_app", __dir__), Dir.pwd)
      Dir.chdir("test_app") { example.run }
    end
  end

  before :all do
    @original_node_env, ENV["NODE_ENV"] = ENV["NODE_ENV"], "development"
    @original_rails_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "development"
  end

  after :all do
    ENV["NODE_ENV"] = @original_node_env
    ENV["RAILS_ENV"] = @original_rails_env
  end

  let(:test_app_path) { Dir.pwd }

  NODE_PACKAGE_MANAGERS.each do |fallback_manager|
    context "when using package_json with #{fallback_manager} as the manager" do
      before do
        manager_name = fallback_manager.split("_")[0]
        manager_version = "1.2.3"
        manager_version = "4.5.6" if fallback_manager == "yarn_berry"

        PackageJson.read.merge! { { "packageManager" => "#{manager_name}@#{manager_version}" } }

        allow(Shakapacker::Utils::Manager).to receive(:error_unless_package_manager_is_obvious!)
      end

      let(:package_json) { PackageJson.read(test_app_path) }

      it "uses the expected package manager", unless: fallback_manager == "yarn_classic" do
        cmd = package_json.manager.native_exec_command("webpack", ["--config", "#{test_app_path}/config/webpack/webpack.config.js"])

        manager_name = fallback_manager.split("_")[0]

        expect(cmd).to start_with(manager_name)
      end

      it "runs the command using the manager" do
        cmd = package_json.manager.native_exec_command("webpack", ["--config", "#{test_app_path}/config/webpack/webpack.config.js"])

        verify_command(cmd)
      end

      it "passes on arguments" do
        cmd = package_json.manager.native_exec_command("webpack", ["--config", "#{test_app_path}/config/webpack/webpack.config.js", "--watch"])

        verify_command(cmd, argv: (["--watch"]))
      end

      it "loads webpack.config.ts if present" do
        ts_config = "#{test_app_path}/config/webpack/webpack.config.ts"
        FileUtils.touch(ts_config)

        cmd = package_json.manager.native_exec_command("webpack", ["--config", ts_config])

        verify_command(cmd)
      ensure
        FileUtils.rm(ts_config)
      end
    end
  end

  include_examples "help and version flags",
                   Shakapacker::Runner,
                   "SHAKAPACKER - Rails Webpack/Rspack Integration"

  describe "help and version flags - runner specific" do
    it "mentions trace-deprecation option in help and exits" do
      expect { Shakapacker::Runner.run(["--help"]) }
        .to output(/--trace-deprecation/).to_stdout
        .and raise_error(SystemExit)
    end

    it "shows examples of usage" do
      expect { Shakapacker::Runner.run(["--help"]) }
        .to output(/Examples/).to_stdout
        .and raise_error(SystemExit)
    end

    it "supports --help=verbose flag" do
      expect { Shakapacker::Runner.run(["--help=verbose"]) }
        .to output(/--help=verbose/).to_stdout
        .and raise_error(SystemExit)
    end

    it "passes --help=verbose to the bundler" do
      allow(Shakapacker::Runner).to receive(:execute_bundler_command) do |flag|
        expect(flag).to eq("--help=verbose")
        [:webpack, "mock verbose help output"]
      end

      expect { Shakapacker::Runner.run(["--help=verbose"]) }
        .to raise_error(SystemExit)
    end
  end

  describe "exit code handling" do
    it "exits with failure code when build fails" do
      Dir.chdir(test_app_path) do
        klass = Shakapacker::WebpackRunner
        instance = klass.new([])

        allow(klass).to receive(:new).and_return(instance)
        allow(Shakapacker::Utils::Manager).to receive(:error_unless_package_manager_is_obvious!)

        # Stub system to simulate failure
        allow(instance).to receive(:system) do |*args|
          system("exit 5")  # Sets $? to exit code 5
          false
        end

        expect { klass.run([]) }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(5)
        end
      end
    end

    it "does not exit when build succeeds" do
      Dir.chdir(test_app_path) do
        klass = Shakapacker::WebpackRunner
        instance = klass.new([])

        allow(klass).to receive(:new).and_return(instance)
        allow(Shakapacker::Utils::Manager).to receive(:error_unless_package_manager_is_obvious!)

        # Stub system to simulate success
        allow(instance).to receive(:system) do |*args|
          system("true")  # Sets $? to successful status
          true
        end

        expect { klass.run([]) }.not_to raise_error
      end
    end
  end

  describe "timing output" do
    it "shows timing for static builds" do
      Dir.chdir(test_app_path) do
        klass = Shakapacker::WebpackRunner
        instance = klass.new([])

        allow(klass).to receive(:new).and_return(instance)
        allow(Shakapacker::Utils::Manager).to receive(:error_unless_package_manager_is_obvious!)

        allow(instance).to receive(:system) do |*args|
          sleep(0.1)  # Simulate build time
          system("true")
          true
        end

        output = capture_stderr { klass.run([]) }

        # Time format can be either "X.XXs" or "M:SS.SSs" for the display, always "X.XXs" in parentheses
        expect(output).to match(/\[Shakapacker\] Completed webpack build in (\d+:\d+\.\d+s|\d+\.\d+s) \(\d+\.\d+s\)/)
      end
    end

    it "does not show timing for watch mode" do
      Dir.chdir(test_app_path) do
        klass = Shakapacker::WebpackRunner
        instance = klass.new(["--watch"])

        allow(klass).to receive(:new).and_return(instance)
        allow(Shakapacker::Utils::Manager).to receive(:error_unless_package_manager_is_obvious!)

        allow(instance).to receive(:system) do |*args|
          system("true")
          true
        end

        output = capture_stderr { klass.run(["--watch"]) }

        expect(output).not_to match(/Completed webpack build/)
      end
    end

    it "formats time correctly for builds under 1 minute" do
      Dir.chdir(test_app_path) do
        klass = Shakapacker::WebpackRunner
        instance = klass.new([])

        allow(klass).to receive(:new).and_return(instance)
        allow(Shakapacker::Utils::Manager).to receive(:error_unless_package_manager_is_obvious!)

        allow(instance).to receive(:system) do |*args|
          system("true")
          true
        end

        output = capture_stderr { klass.run([]) }

        # Should show format like "3.29s (3.29s)" without minutes
        expect(output).to match(/\[Shakapacker\] Completed webpack build in \d+\.\d+s \(\d+\.\d+s\)/)
        expect(output).not_to match(/\d+:\d+\.\d+s/)
      end
    end
  end

  describe "stdout/stderr separation for JSON output" do
    it "does not write [Shakapacker] log messages to stdout" do
      Dir.chdir(test_app_path) do
        klass = Shakapacker::WebpackRunner
        instance = klass.new(["--json"])

        allow(klass).to receive(:new).and_return(instance)
        allow(Shakapacker::Utils::Manager).to receive(:error_unless_package_manager_is_obvious!)

        allow(instance).to receive(:system) do |*args|
          system("true")
          true
        end

        stdout_output, stderr_output = capture_stdout_and_stderr { klass.run(["--json"]) }

        # Stdout should NOT contain [Shakapacker] log messages
        expect(stdout_output).not_to match(/\[Shakapacker\]/)

        # Stderr SHOULD contain [Shakapacker] log messages
        expect(stderr_output).to match(/\[Shakapacker\]/)
      end
    end

    it "keeps stdout clean for valid JSON output when using --json flag" do
      Dir.chdir(test_app_path) do
        klass = Shakapacker::WebpackRunner
        instance = klass.new(["--profile", "--json"])

        allow(klass).to receive(:new).and_return(instance)
        allow(Shakapacker::Utils::Manager).to receive(:error_unless_package_manager_is_obvious!)

        allow(instance).to receive(:system) do |*args|
          system("true")
          true
        end

        stdout_output, = capture_stdout_and_stderr { klass.run(["--profile", "--json"]) }

        # Stdout should be empty (no log messages polluting it)
        # The actual JSON would come from webpack itself, not shakapacker
        expect(stdout_output).to be_empty
      end
    end
  end

  private

    def capture_stdout_and_stderr
      old_stdout = $stdout
      old_stderr = $stderr
      $stdout = StringIO.new
      $stderr = StringIO.new
      yield
      [$stdout.string, $stderr.string]
    ensure
      $stdout = old_stdout
      $stderr = old_stderr
    end

    def capture_stderr
      old_stderr = $stderr
      $stderr = StringIO.new
      yield
      $stderr.string
    ensure
      $stderr = old_stderr
    end

    def verify_command(cmd, argv: [])
      Dir.chdir(test_app_path) do
        klass = Shakapacker::WebpackRunner
        instance = klass.new(argv)

        allow(klass).to receive(:new).and_return(instance)
        # Stub system to set $? to successful status
        allow(instance).to receive(:system) do |*args|
          system("true")  # Sets $? to successful status
          true
        end

        klass.run(argv)

        expect(instance).to have_received(:system).with(Shakapacker::Compiler.env, *cmd)
        expect(Shakapacker::Utils::Manager).to have_received(:error_unless_package_manager_is_obvious!)
      end
    end
end

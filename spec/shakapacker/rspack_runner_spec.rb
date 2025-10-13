require_relative "spec_helper_initializer"
require_relative "shared/help_and_version_examples"
require "shakapacker/rspack_runner"
require_relative "../support/package_json_helpers"

describe "RspackRunner" do
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
        cmd = package_json.manager.native_exec_command("rspack", ["--config", "#{test_app_path}/config/webpack/webpack.config.js"])

        manager_name = fallback_manager.split("_")[0]

        expect(cmd).to start_with(manager_name)
      end

      it "runs the command using the manager" do
        cmd = package_json.manager.native_exec_command("rspack", ["--config", "#{test_app_path}/config/webpack/webpack.config.js"])

        verify_command(cmd)
      end

      it "passes on arguments" do
        cmd = package_json.manager.native_exec_command("rspack", ["--config", "#{test_app_path}/config/webpack/webpack.config.js", "--watch"])

        verify_command(cmd, argv: (["--watch"]))
      end

      it "loads webpack.config.ts if present" do
        ts_config = "#{test_app_path}/config/webpack/webpack.config.ts"
        FileUtils.touch(ts_config)

        cmd = package_json.manager.native_exec_command("rspack", ["--config", ts_config])

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
  end

  describe "exit code handling" do
    it "exits with failure code when build fails" do
      Dir.chdir(test_app_path) do
        klass = Shakapacker::RspackRunner
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
        klass = Shakapacker::RspackRunner
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
        klass = Shakapacker::RspackRunner
        instance = klass.new([])

        allow(klass).to receive(:new).and_return(instance)
        allow(Shakapacker::Utils::Manager).to receive(:error_unless_package_manager_is_obvious!)

        allow(instance).to receive(:system) do |*args|
          sleep(0.1)  # Simulate build time
          system("true")
          true
        end

        output = capture_stdout { klass.run([]) }

        # The test app may have webpack config, so bundler name could be either
        expect(output).to match(/\[Shakapacker\] Completed (webpack|rspack) build in \d+\.\d+s \(\d+\.\d+s\)/)
      end
    end

    it "does not show timing for watch mode with --watch flag" do
      Dir.chdir(test_app_path) do
        klass = Shakapacker::RspackRunner
        instance = klass.new(["--watch"])

        allow(klass).to receive(:new).and_return(instance)
        allow(Shakapacker::Utils::Manager).to receive(:error_unless_package_manager_is_obvious!)

        allow(instance).to receive(:system) do |*args|
          system("true")
          true
        end

        output = capture_stdout { klass.run(["--watch"]) }

        expect(output).not_to match(/Completed (webpack|rspack) build/)
      end
    end

    it "does not show timing for watch mode with -w flag" do
      Dir.chdir(test_app_path) do
        klass = Shakapacker::RspackRunner
        instance = klass.new(["-w"])

        allow(klass).to receive(:new).and_return(instance)
        allow(Shakapacker::Utils::Manager).to receive(:error_unless_package_manager_is_obvious!)

        allow(instance).to receive(:system) do |*args|
          system("true")
          true
        end

        output = capture_stdout { klass.run(["-w"]) }

        expect(output).not_to match(/Completed (webpack|rspack) build/)
      end
    end
  end

  private

    def capture_stdout
      old_stdout = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = old_stdout
    end

    def verify_command(cmd, argv: [])
      Dir.chdir(test_app_path) do
        klass = Shakapacker::RspackRunner
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

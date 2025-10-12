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

    it "mentions mode option users can set" do
      expect { Shakapacker::Runner.run(["--help"]) }
        .to output(/--mode MODE/).to_stdout
        .and raise_error(SystemExit)
    end
  end

  private

    def verify_command(cmd, argv: [])
      Dir.chdir(test_app_path) do
        klass = Shakapacker::RspackRunner
        instance = klass.new(argv)

        allow(klass).to receive(:new).and_return(instance)
        allow(Kernel).to receive(:exec)

        klass.run(argv)

        expect(Kernel).to have_received(:exec).with(Shakapacker::Compiler.env, *cmd)
        expect(Shakapacker::Utils::Manager).to have_received(:error_unless_package_manager_is_obvious!)
      end
    end
end

require_relative "spec_helper_initializer"
require "shakapacker/dev_server_runner"

describe "DevServerRunner" do
  around do |example|
    within_temp_directory do
      FileUtils.cp_r(File.expand_path("./test_app", __dir__), Dir.pwd)
      Dir.chdir("test_app") { example.run }
    end
  end

  before do
    @original_node_env, ENV["NODE_ENV"] = ENV["NODE_ENV"], "development"
    @original_rails_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "development"
    @original_shakapacker_config = ENV["SHAKAPACKER_CONFIG"]
  end

  after do
    ENV["NODE_ENV"] = @original_node_env
    ENV["RAILS_ENV"] = @original_rails_env
    ENV["SHAKAPACKER_CONFIG"] = @original_shakapacker_config
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
        cmd = package_json.manager.native_exec_command("webpack", ["serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js"])

        manager_name = fallback_manager.split("_")[0]

        expect(cmd).to start_with(manager_name)
      end

      it "runs the command using the manager" do
        cmd = package_json.manager.native_exec_command("webpack", ["serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js"])

        verify_command(cmd)
      end

      it "passes on arguments" do
        cmd = package_json.manager.native_exec_command("webpack", ["serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js", "--quiet"])

        verify_command(cmd, argv: (["--quiet"]))
      end

      it "does not automatically pass the --https flag" do
        cmd = package_json.manager.native_exec_command("webpack", ["serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js"])

        allow(Shakapacker::DevServer).to receive(:new).and_return(
          double(
            host: "localhost",
            port: "3035",
            pretty?: false,
            protocol: "https",
            hmr?: true
          )
        )

        verify_command(cmd)
      end

      it "supports the https flag" do
        cmd = package_json.manager.native_exec_command("webpack", ["serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js", "--https"])

        allow(Shakapacker::DevServer).to receive(:new).and_return(
          double(
            host: "localhost",
            port: "3035",
            pretty?: false,
            protocol: "https",
            hmr?: true
          )
        )

        verify_command(cmd, argv: ["--https"])
      end

      it "supports disabling hot module reloading" do
        cmd = package_json.manager.native_exec_command("webpack", ["serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js", "--no-hot"])

        allow(Shakapacker::DevServer).to receive(:new).and_return(
          double(
            host: "localhost",
            port: "3035",
            pretty?: false,
            protocol: "http",
            hmr?: false
          )
        )

        verify_command(cmd)
      end

      it "accepts environment variables" do
        cmd = package_json.manager.native_exec_command("webpack", ["serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js"])

        env = Shakapacker::Compiler.env.dup
        ENV["SHAKAPACKER_CONFIG"] = env["SHAKAPACKER_CONFIG"] = "#{test_app_path}/config/shakapacker_other_location.yml"
        env["WEBPACK_SERVE"] = "true"

        verify_command(cmd, env: env)
      end
    end
  end

  describe "help and version flags" do
    before do
      allow(Shakapacker::Utils::Manager).to receive(:error_unless_package_manager_is_obvious!)
      allow(Kernel).to receive(:exec)
    end

    it "prints custom help message for --help flag" do
      expect { Shakapacker::DevServerRunner.run(["--help"]) }
        .to output(/SHAKAPACKER DEV SERVER/).to_stdout
    end

    it "prints custom help message for -h flag" do
      expect { Shakapacker::DevServerRunner.run(["-h"]) }
        .to output(/SHAKAPACKER DEV SERVER/).to_stdout
    end

    it "includes Shakapacker-specific options in help" do
      expect { Shakapacker::DevServerRunner.run(["--help"]) }
        .to output(/--debug-shakapacker/).to_stdout
    end

    it "mentions configuration in help" do
      expect { Shakapacker::DevServerRunner.run(["--help"]) }
        .to output(/config\/shakapacker\.yml/).to_stdout
    end

    it "shows separator before bundler options" do
      expect { Shakapacker::DevServerRunner.run(["--help"]) }
        .to output(/WEBPACK\/RSPACK DEV SERVER OPTIONS/).to_stdout
    end

    it "continues to pass --help through to bundler after showing Shakapacker help" do
      Shakapacker::DevServerRunner.run(["--help"])
      expect(Kernel).to have_received(:exec)
    end

    it "prints version for --version flag" do
      expect { Shakapacker::DevServerRunner.run(["--version"]) }
        .to output(/Shakapacker #{Shakapacker::VERSION}/).to_stdout
    end

    it "prints version for -v flag" do
      expect { Shakapacker::DevServerRunner.run(["-v"]) }
        .to output(/Shakapacker #{Shakapacker::VERSION}/).to_stdout
    end

    it "continues to pass --version through to bundler after showing Shakapacker version" do
      Shakapacker::DevServerRunner.run(["--version"])
      expect(Kernel).to have_received(:exec)
    end
  end

  private

    def verify_command(cmd, argv: [], env: Shakapacker::Compiler.env)
      Dir.chdir(test_app_path) do
        klass = Shakapacker::DevServerRunner
        instance = klass.new(argv)

        allow(klass).to receive(:new).and_return(instance)
        allow(Kernel).to receive(:exec).with(env, *cmd)

        klass.run(argv)

        expect(Kernel).to have_received(:exec).with(env, *cmd)
        expect(Shakapacker::Utils::Manager).to have_received(:error_unless_package_manager_is_obvious!)
      end
    end
end

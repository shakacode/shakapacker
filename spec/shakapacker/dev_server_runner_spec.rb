require_relative "spec_helper_initializer"
require_relative "shared/help_and_version_examples"
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

  include_examples "help and version flags",
                   Shakapacker::DevServerRunner,
                   "SHAKAPACKER DEV SERVER"

  describe "help and version flags - dev server specific" do
    it "mentions configuration in help and exits" do
      expect { Shakapacker::DevServerRunner.run(["--help"]) }
        .to output(/config\/shakapacker\.yml/).to_stdout
        .and raise_error(SystemExit)
    end

    it "mentions host/port are managed by config" do
      expect { Shakapacker::DevServerRunner.run(["--help"]) }
        .to output(/--host.*Set from dev_server\.host/).to_stdout
        .and raise_error(SystemExit)
    end
  end

  describe "NODE_ENV environment variable" do
    it "sets NODE_ENV when not already set" do
      original_node_env = ENV.delete("NODE_ENV")

      begin
        Dir.chdir(test_app_path) do
          klass = Shakapacker::DevServerRunner

          allow(Shakapacker::Utils::Manager).to receive(:error_unless_package_manager_is_obvious!)

          instance = klass.new([])

          allow(klass).to receive(:new).and_return(instance)

          # Stub build_cmd and system to prevent actual execution
          allow(instance).to receive(:build_cmd).and_return(["webpack", "serve"])
          allow(instance).to receive(:system) do |*args|
            system("true")  # Sets $? to successful status
            true
          end

          klass.run([])

          expect(ENV["NODE_ENV"]).to eq("development")
        end
      ensure
        ENV["NODE_ENV"] = original_node_env if original_node_env
      end
    end
  end

  private

    def verify_command(cmd, argv: [], env: Shakapacker::Compiler.env)
      Dir.chdir(test_app_path) do
        klass = Shakapacker::DevServerRunner
        instance = klass.new(argv)

        allow(klass).to receive(:new).and_return(instance)
        # Stub system to set $? to successful status
        allow(instance).to receive(:system) do |*args|
          system("true")  # Sets $? to successful status
          true
        end

        klass.run(argv)

        expect(instance).to have_received(:system).with(env, *cmd)
        expect(Shakapacker::Utils::Manager).to have_received(:error_unless_package_manager_is_obvious!)
      end
    end
end

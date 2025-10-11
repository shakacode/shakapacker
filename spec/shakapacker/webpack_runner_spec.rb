require_relative "spec_helper_initializer"
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

  describe "help and version flags" do
    before do
      allow(Shakapacker::Utils::Manager).to receive(:error_unless_package_manager_is_obvious!)
      allow(Kernel).to receive(:exec)
    end

    it "prints custom help message for --help flag" do
      expect { Shakapacker::Runner.run(["--help"]) }
        .to output(/SHAKAPACKER - Rails Webpack\/Rspack Integration/).to_stdout
    end

    it "prints custom help message for -h flag" do
      expect { Shakapacker::Runner.run(["-h"]) }
        .to output(/SHAKAPACKER - Rails Webpack\/Rspack Integration/).to_stdout
    end

    it "includes Shakapacker-specific options in help" do
      expect { Shakapacker::Runner.run(["--help"]) }
        .to output(/--debug-shakapacker/).to_stdout
    end

    it "mentions trace-deprecation option in help" do
      expect { Shakapacker::Runner.run(["--help"]) }
        .to output(/--trace-deprecation/).to_stdout
    end

    it "shows separator before bundler options" do
      expect { Shakapacker::Runner.run(["--help"]) }
        .to output(/WEBPACK\/RSPACK OPTIONS/).to_stdout
    end

    it "continues to pass --help through to bundler after showing Shakapacker help" do
      Shakapacker::Runner.run(["--help"])
      expect(Kernel).to have_received(:exec)
    end

    it "prints version for --version flag" do
      expect { Shakapacker::Runner.run(["--version"]) }
        .to output(/Shakapacker #{Shakapacker::VERSION}/).to_stdout
    end

    it "prints version for -v flag" do
      expect { Shakapacker::Runner.run(["-v"]) }
        .to output(/Shakapacker #{Shakapacker::VERSION}/).to_stdout
    end

    it "continues to pass --version through to bundler after showing Shakapacker version" do
      Shakapacker::Runner.run(["--version"])
      expect(Kernel).to have_received(:exec)
    end
  end

  private

    def verify_command(cmd, argv: [])
      Dir.chdir(test_app_path) do
        klass = Shakapacker::WebpackRunner
        instance = klass.new(argv)

        allow(klass).to receive(:new).and_return(instance)
        allow(Kernel).to receive(:exec)

        klass.run(argv)

        expect(Kernel).to have_received(:exec).with(Shakapacker::Compiler.env, *cmd)
        expect(Shakapacker::Utils::Manager).to have_received(:error_unless_package_manager_is_obvious!)
      end
    end
end

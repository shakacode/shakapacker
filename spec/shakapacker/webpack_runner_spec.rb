require_relative "spec_helper_initializer"
require "shakapacker/webpack_runner"

describe "WebpackRunner" do
  before :all do
    @original_node_env, ENV["NODE_ENV"] = ENV["NODE_ENV"], "development"
    @original_rails_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "development"
  end

  after :all do
    ENV["NODE_ENV"] = @original_node_env
    ENV["RAILS_ENV"] = @original_rails_env
  end

  let(:test_app_path) { File.expand_path("./test_app", __dir__) }

  NODE_PACKAGE_MANAGERS.each do |fallback_manager|
    context "when using package_json with #{fallback_manager} as the manager" do
      with_package_json_fallback_manager(fallback_manager)

      let(:package_json) { PackageJson.read(test_app_path) }

      require "package_json"

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
      end
    end
end

require_relative "spec_helper_initializer"
# Requiring from webpacker directory to ensure old ./bin/webpacker-dev-server works fine
require "webpacker/webpack_runner"

describe "WebpackRunner" do
  before :all do
    @original_node_env, ENV["NODE_ENV"] = ENV["NODE_ENV"], "development"
    @original_rails_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "development"
  end

  after :all do
    ENV["NODE_ENV"] = @original_node_env
    ENV["RAILS_ENV"] = @original_rails_env
  end

  let(:test_app_path) { File.expand_path("./webpacker_test_app", __dir__) }

  NODE_PACKAGE_MANAGERS.each do |fallback_manager|
    context "when using package_json with #{fallback_manager} as the manager" do
      with_use_package_json_gem(enabled: true, fallback_manager: fallback_manager)

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

  context "when not using package_json" do
    with_use_package_json_gem(enabled: false)

    it "supports running via node_modules" do
      cmd = ["#{test_app_path}/node_modules/.bin/webpack", "--config", "#{test_app_path}/config/webpack/webpack.config.js"]

      verify_command(cmd, use_node_modules: true)
    end

    it "supports running via yarn" do
      cmd = ["yarn", "webpack", "--config", "#{test_app_path}/config/webpack/webpack.config.js"]

      verify_command(cmd, use_node_modules: false)
    end

    it "passes on arguments" do
      cmd = ["#{test_app_path}/node_modules/.bin/webpack", "--config", "#{test_app_path}/config/webpack/webpack.config.js", "--watch"]

      verify_command(cmd, argv: ["--watch"])
    end
  end

  private

    def verify_command(cmd, use_node_modules: true, argv: [])
      Dir.chdir(test_app_path) do
        klass = Webpacker::WebpackRunner
        instance = klass.new(argv)

        allow(klass).to receive(:new).and_return(instance)
        allow(instance).to receive(:node_modules_bin_exist?).and_return(use_node_modules)
        allow(Kernel).to receive(:exec)

        klass.run(argv)

        expect(Kernel).to have_received(:exec).with(Webpacker::Compiler.env, *cmd)
      end
    end
end

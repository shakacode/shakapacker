require "webpacker/dev_server_runner"

describe "DevServerRunner" do
  before do
    @original_node_env, ENV["NODE_ENV"] = ENV["NODE_ENV"], "development"
    @original_rails_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "development"
    @original_webpacker_config = ENV["WEBPACKER_CONFIG"]
  end

  after do
    ENV["NODE_ENV"] = @original_node_env
    ENV["RAILS_ENV"] = @original_rails_env
    ENV["WEBPACKER_CONFIG"] = @original_webpacker_config
  end

  let(:test_app_path) { File.expand_path("test_app", __dir__) }

  it "run cmd via node modules" do
    cmd = ["#{test_app_path}/node_modules/.bin/webpack", "serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js"]
    verify_command(cmd, use_node_modules: true)
  end
  it "run cmd via yarn" do
    cmd = ["yarn", "webpack", "serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js"]
    verify_command(cmd, use_node_modules: false)
  end
  it "run cmd argv" do
    cmd = ["#{test_app_path}/node_modules/.bin/webpack", "serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js", "--quiet"]
    verify_command(cmd, argv: (["--quiet"]))
  end
  it "run cmd argv with https" do
    cmd = ["#{test_app_path}/node_modules/.bin/webpack", "serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js", "--https"]

    dev_server = double()
    allow(dev_server).to receive(:host).and_return("localhost")
    allow(dev_server).to receive(:port).and_return("3035")
    allow(dev_server).to receive(:pretty?).and_return(false)
    allow(dev_server).to receive(:https?).and_return(true)
    allow(dev_server).to receive(:hmr?).and_return(false)

    allow(Webpacker::DevServer).to receive(:new) do
      verify_command(cmd, argv: (["--https"]))
    end.and_return(dev_server)
  end
  it "accepts environment variables" do
    cmd = ["#{test_app_path}/node_modules/.bin/webpack", "serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js"]
    env = Webpacker::Compiler.env.dup
    ENV["WEBPACKER_CONFIG"] = env["WEBPACKER_CONFIG"] = "#{test_app_path}/config/webpacker_other_location.yml"
    env["WEBPACK_SERVE"] = "true"
    verify_command(cmd, env: env)
  end

  private

    def verify_command(cmd, use_node_modules: true, argv: [], env: Webpacker::Compiler.env)
      cwd = Dir.pwd
      Dir.chdir(test_app_path)
      klass = Webpacker::DevServerRunner
      instance = klass.new(argv)

      allow(klass).to receive(:new).and_return(instance)
      allow(instance).to receive(:node_modules_bin_exist?).and_return(use_node_modules)
      allow(Kernel).to receive(:exec).with(env, *cmd)

      klass.run(argv)

      expect(Kernel).to have_received(:exec).with(env, *cmd)

      ensure
        Dir.chdir(cwd)
    end
end

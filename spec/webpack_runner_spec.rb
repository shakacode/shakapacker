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

  it "runs cmd via node_modules" do
    cmd = ["#{test_app_path}/node_modules/.bin/webpack", "--config", "#{test_app_path}/config/webpack/webpack.config.js"]

    verify_command(cmd, use_node_modules: true)
  end

  it "runs cmd via yarn" do
    cmd = ["yarn", "webpack", "--config", "#{test_app_path}/config/webpack/webpack.config.js"]

    verify_command(cmd, use_node_modules: false)
  end

  it "runs cmd argv" do
    cmd = ["#{test_app_path}/node_modules/.bin/webpack", "--config", "#{test_app_path}/config/webpack/webpack.config.js", "--watch"]

    verify_command(cmd, argv: ["--watch"])
  end

  private
    def test_app_path
      File.expand_path("test_app", __dir__)
    end

    def verify_command(cmd, use_node_modules: true, argv: [])
      cwd = Dir.pwd
      Dir.chdir(test_app_path)

      klass = Shakapacker::WebpackRunner
      instance = klass.new(argv)

      allow(klass).to receive(:new).and_return(instance)
      allow(instance).to receive(:node_modules_bin_exist?).and_return(use_node_modules)
      allow(Kernel).to receive(:exec)

      klass.run(argv)

      expect(Kernel).to have_received(:exec).with(Shakapacker::Compiler.env, *cmd)
    ensure
      Dir.chdir(cwd)
    end
end

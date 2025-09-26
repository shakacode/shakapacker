require_relative "spec_helper_initializer"
require "shakapacker/rspack_runner"
require "shakapacker/webpack_runner"
require_relative "../support/package_json_helpers"

describe "Config Path Resolution" do
  around do |example|
    within_temp_directory do
      FileUtils.cp_r(File.expand_path("./test_app", __dir__), Dir.pwd)
      Dir.chdir("test_app") { example.run }
    end
  end

  before do
    allow(Shakapacker::Utils::Manager).to receive(:error_unless_package_manager_is_obvious!)
  end

  context "when assets bundler is webpack" do
    before do
      # Set assets bundler to webpack in config
      config_path = File.join(Dir.pwd, "config/shakapacker.yml")
      # error rescue is for support of ruby 2.7 ~ 3.0
      config = begin
        YAML.load_file(config_path, aliases: true)
      rescue ArgumentError
        YAML.load_file(config_path)
      end
      config["development"]["assets_bundler"] = "webpack"
      File.write(config_path, YAML.dump(config))
    end

    it "uses webpack config path" do
      runner = Shakapacker::WebpackRunner.new([])
      expect(runner.instance_variable_get(:@webpack_config)).to match(/webpack\.config\.js$/)
    end
  end

  context "when assets bundler is rspack" do
    before do
      # Set assets bundler to rspack in config
      config_path = File.join(Dir.pwd, "config/shakapacker.yml")
      # error rescue is for support of ruby 2.7 ~ 3.0
      config = begin
        YAML.load_file(config_path, aliases: true)
      rescue ArgumentError
        YAML.load_file(config_path)
      end
      config["development"] ||= {}
      config["development"]["assets_bundler"] = "rspack"
      File.write(config_path, YAML.dump(config))
    end

    context "with no config files present" do
      before do
        FileUtils.rm_f("config/webpack/webpack.config.js")
      end

      it "exits with error message" do
        expect { Shakapacker::RspackRunner.new([]) }.to raise_error(SystemExit)
      end
    end
  end
end

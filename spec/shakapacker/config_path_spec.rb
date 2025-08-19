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

  context "when bundler is webpack" do
    before do
      # Set bundler to webpack in config
      config_path = File.join(Dir.pwd, "config/shakapacker.yml")
      config = YAML.load_file(config_path, aliases: true)
      config["development"]["bundler"] = "webpack"
      File.write(config_path, YAML.dump(config))
    end

    it "uses webpack config path" do
      runner = Shakapacker::WebpackRunner.new([])
      expect(runner.instance_variable_get(:@webpack_config)).to match(/webpack\.config\.js$/)
    end
  end

  context "when bundler is rspack" do
    before do
      # Set bundler to rspack in config
      config_path = File.join(Dir.pwd, "config/shakapacker.yml")
      config = YAML.load_file(config_path, aliases: true)
      config["development"] ||= {}
      config["development"]["bundler"] = "rspack"
      File.write(config_path, YAML.dump(config))
    end

    context "with rspack config file present" do
      before do
        # Create rspack config directory and file
        FileUtils.mkdir_p("config/rspack")
        File.write("config/rspack/rspack.config.js", "module.exports = {}")
      end

      it "uses rspack config path" do
        runner = Shakapacker::RspackRunner.new([])
        expect(runner.instance_variable_get(:@webpack_config)).to match(/rspack\.config\.js$/)
      end
    end

    context "with only webpack config file present (fallback scenario)" do
      it "uses webpack config path with deprecation warning" do
        expect($stderr).to receive(:puts).with(/DEPRECATION WARNING/)
        expect($stderr).to receive(:puts).with(/Please create config\/rspack\/rspack\.config\.js/)
        expect($stderr).to receive(:puts).with(/Using:/)
        
        runner = Shakapacker::RspackRunner.new([])
        expect(runner.instance_variable_get(:@webpack_config)).to match(/webpack\.config\.js$/)
      end
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
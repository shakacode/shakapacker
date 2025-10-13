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

    context "with no config files present" do
      before do
        FileUtils.rm_f("config/webpack/webpack.config.js")
        FileUtils.rm_f("config/webpack/webpack.config.ts")
      end

      it "exits with helpful error message suggesting assets_bundler_config_path" do
        old_stderr = $stderr
        $stderr = StringIO.new

        expect { Shakapacker::WebpackRunner.new([]) }.to raise_error(SystemExit)

        stderr_output = $stderr.string
        expect(stderr_output).to match(/assets_bundler_config_path/)
        expect(stderr_output).to match(/Current configured path/)
      ensure
        $stderr = old_stderr
      end
    end

    context "with custom assets_bundler_config_path" do
      before do
        # Create a custom config directory
        FileUtils.mkdir_p("custom_config")
        FileUtils.cp("config/webpack/webpack.config.js", "custom_config/webpack.config.js")

        # Set custom config path
        config_path = File.join(Dir.pwd, "config/shakapacker.yml")
        config = begin
          YAML.load_file(config_path, aliases: true)
        rescue ArgumentError
          YAML.load_file(config_path)
        end
        config["development"]["assets_bundler"] = "webpack"
        config["development"]["assets_bundler_config_path"] = "custom_config"
        File.write(config_path, YAML.dump(config))
      end

      it "uses custom config path" do
        runner = Shakapacker::WebpackRunner.new([])
        expect(runner.instance_variable_get(:@webpack_config)).to match(%r{custom_config/webpack\.config\.js$})
      end
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

      it "exits with helpful error message suggesting assets_bundler_config_path" do
        old_stderr = $stderr
        $stderr = StringIO.new

        expect { Shakapacker::RspackRunner.new([]) }.to raise_error(SystemExit)

        stderr_output = $stderr.string
        expect(stderr_output).to match(/assets_bundler_config_path/)
        expect(stderr_output).to match(/Current configured path/)
      ensure
        $stderr = old_stderr
      end
    end
  end

  describe "Configuration#assets_bundler_config_path" do
    let(:config) do
      Shakapacker::Configuration.new(
        root_path: Pathname.new(Dir.pwd),
        config_path: Pathname.new(File.join(Dir.pwd, "config/shakapacker.yml")),
        env: "development"
      )
    end

    context "when no custom path is set" do
      before do
        config_path = File.join(Dir.pwd, "config/shakapacker.yml")
        config_data = begin
          YAML.load_file(config_path, aliases: true)
        rescue ArgumentError
          YAML.load_file(config_path)
        end
        config_data["development"].delete("assets_bundler_config_path") if config_data["development"]
        File.write(config_path, YAML.dump(config_data))
      end

      it "returns default webpack path when bundler is webpack" do
        config_path = File.join(Dir.pwd, "config/shakapacker.yml")
        config_data = begin
          YAML.load_file(config_path, aliases: true)
        rescue ArgumentError
          YAML.load_file(config_path)
        end
        config_data["development"] ||= {}
        config_data["development"]["assets_bundler"] = "webpack"
        File.write(config_path, YAML.dump(config_data))

        expect(config.assets_bundler_config_path).to eq("config/webpack")
      end

      it "returns default rspack path when bundler is rspack" do
        config_path = File.join(Dir.pwd, "config/shakapacker.yml")
        config_data = begin
          YAML.load_file(config_path, aliases: true)
        rescue ArgumentError
          YAML.load_file(config_path)
        end
        config_data["development"] ||= {}
        config_data["development"]["assets_bundler"] = "rspack"
        File.write(config_path, YAML.dump(config_data))

        expect(config.assets_bundler_config_path).to eq("config/rspack")
      end
    end

    context "when custom path is set" do
      before do
        config_path = File.join(Dir.pwd, "config/shakapacker.yml")
        config_data = begin
          YAML.load_file(config_path, aliases: true)
        rescue ArgumentError
          YAML.load_file(config_path)
        end
        config_data["development"] ||= {}
        config_data["development"]["assets_bundler_config_path"] = "custom/path"
        File.write(config_path, YAML.dump(config_data))
      end

      it "returns the custom path" do
        expect(config.assets_bundler_config_path).to eq("custom/path")
      end
    end

    context "when root directory is specified" do
      before do
        config_path = File.join(Dir.pwd, "config/shakapacker.yml")
        config_data = begin
          YAML.load_file(config_path, aliases: true)
        rescue ArgumentError
          YAML.load_file(config_path)
        end
        config_data["development"] ||= {}
        config_data["development"]["assets_bundler_config_path"] = "."
        File.write(config_path, YAML.dump(config_data))
      end

      it "returns the root directory" do
        expect(config.assets_bundler_config_path).to eq(".")
      end
    end
  end
end

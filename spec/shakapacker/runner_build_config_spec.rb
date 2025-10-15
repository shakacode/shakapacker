require_relative "spec_helper_initializer"
require "shakapacker/runner"
require "shakapacker/dev_server_runner"

describe "Runner with build configs" do
  around do |example|
    within_temp_directory do
      FileUtils.cp_r(File.expand_path("./test_app", __dir__), Dir.pwd)
      Dir.chdir("test_app") { example.run }
    end
  end

  before do
    @original_node_env, ENV["NODE_ENV"] = ENV["NODE_ENV"], nil
    @original_rails_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], nil
    allow(Shakapacker::Utils::Manager).to receive(:error_unless_package_manager_is_obvious!)
  end

  after do
    ENV["NODE_ENV"] = @original_node_env
    ENV["RAILS_ENV"] = @original_rails_env
    File.delete(".bundler-config.yml") if File.exist?(".bundler-config.yml")
  end

  let(:test_app_path) { Dir.pwd }

  describe "running build by name" do
    context "when .bundler-config.yml exists with prod build" do
      before do
        File.write(".bundler-config.yml", <<~YAML)
          builds:
            prod:
              description: Production build
              bundler: webpack
              environment:
                NODE_ENV: production
                RAILS_ENV: production
              outputs:
                - client
                - server
        YAML
      end

      it "loads and applies build configuration" do
        klass = Shakapacker::Runner
        instance = klass.new([], nil)

        allow(klass).to receive(:new).and_return(instance)
        allow(instance).to receive(:system).and_return(true)

        output = capture_stdout do
          klass.run(["prod"])
        end

        expect(output).to include("Running build: prod")
        expect(output).to include("Description: Production build")
        expect(output).to include("Bundler: webpack")
        expect(ENV["NODE_ENV"]).to eq("production")
        expect(ENV["RAILS_ENV"]).to eq("production")
      end
    end

    context "when .bundler-config.yml exists with HMR build" do
      before do
        File.write(".bundler-config.yml", <<~YAML)
          builds:
            dev-hmr:
              description: HMR development build
              bundler: webpack
              environment:
                NODE_ENV: development
                RAILS_ENV: development
                WEBPACK_SERVE: "true"
              outputs:
                - client
        YAML
      end

      it "delegates to DevServerRunner when WEBPACK_SERVE=true" do
        klass = Shakapacker::Runner
        dev_server_klass = Shakapacker::DevServerRunner
        dev_server_instance = dev_server_klass.new([], nil)

        allow(dev_server_klass).to receive(:run_with_build_config).and_call_original
        allow(dev_server_klass).to receive(:new).and_return(dev_server_instance)
        allow(dev_server_instance).to receive(:run).and_return(nil)

        output = capture_stdout do
          klass.run(["dev-hmr"])
        end

        expect(dev_server_klass).to have_received(:run_with_build_config)
        expect(output).to include("Running dev server for build: dev-hmr")
        expect(output).to include("Description: HMR development build")
        expect(ENV["WEBPACK_SERVE"]).to eq("true")
      end
    end

    context "when build name not found" do
      before do
        File.write(".bundler-config.yml", <<~YAML)
          builds:
            prod:
              description: Production build
              outputs:
                - client
        YAML
      end

      it "falls back to normal argv processing" do
        klass = Shakapacker::Runner
        instance = klass.new(["nonexistent"], nil)

        allow(klass).to receive(:new).and_return(instance)
        allow(instance).to receive(:system).and_return(true)

        output = capture_stdout do
          klass.run(["nonexistent"])
        end

        # Should process as normal webpack command, not as build config
        expect(output).not_to include("Running build:")
        expect(output).to include("Preparing environment for assets bundler")
      end
    end

    context "when .bundler-config.yml does not exist" do
      it "runs normally without build config" do
        klass = Shakapacker::Runner
        instance = klass.new([], nil)

        allow(klass).to receive(:new).and_return(instance)
        allow(instance).to receive(:system).and_return(true)

        output = capture_stdout do
          klass.run([])
        end

        expect(output).not_to include("Running build:")
        expect(output).to include("Preparing environment for assets bundler")
      end
    end

    context "with custom config file path" do
      before do
        File.write(".bundler-config.yml", <<~YAML)
          builds:
            custom:
              description: Custom config build
              bundler: webpack
              config: config/webpack/webpack.config.js
              environment:
                NODE_ENV: development
              outputs:
                - client
        YAML
      end

      it "uses the config file path from build config" do
        klass = Shakapacker::Runner
        loader = Shakapacker::BuildConfigLoader.new

        build_config = loader.resolve_build_config("custom")

        # Verify build config has config_file set
        expect(build_config[:config_file]).to eq("config/webpack/webpack.config.js")

        instance = klass.new([], build_config)

        # Verify the webpack_config is set correctly
        expect(instance.instance_variable_get(:@webpack_config)).to include("config/webpack/webpack.config.js")
      end
    end
  end

  describe "DevServerRunner with build configs" do
    context "when running with build name" do
      before do
        File.write(".bundler-config.yml", <<~YAML)
          builds:
            dev:
              description: Dev server build
              bundler: webpack
              environment:
                NODE_ENV: development
                RAILS_ENV: development
                WEBPACK_SERVE: "true"
              outputs:
                - client
        YAML
      end

      it "loads and applies build configuration" do
        klass = Shakapacker::DevServerRunner
        instance = klass.new([], nil)

        allow(klass).to receive(:new).and_return(instance)
        allow(instance).to receive(:run).and_return(nil)

        output = capture_stdout do
          klass.run(["dev"])
        end

        expect(output).to include("Running dev server for build: dev")
        expect(output).to include("Description: Dev server build")
        expect(ENV["NODE_ENV"]).to eq("development")
        expect(ENV["WEBPACK_SERVE"]).to eq("true")
      end
    end
  end

  private

    def capture_stdout
      old_stdout = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = old_stdout
    end
end

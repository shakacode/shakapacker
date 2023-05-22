require "pathname"
require "fileutils"
require "rake"
require "shakapacker/utils/misc"
require "shakapacker/utils/version_syntax_converter"

GEM_ROOT = Pathname.new(File.expand_path("../../..", __FILE__))
SPEC_PATH = Pathname.new(File.expand_path("../", __FILE__))
# BASE_RAILS_APP_PATH = SPEC_PATH.join("base-rails-app")
TEMP_RAILS_APP_PATH = SPEC_PATH.join("temp-rails-app")

describe "Generator" do
  before :all do
    # Don't use --skip-git because we want .gitignore file to exist in the project
    sh_in_dir(SPEC_PATH, %(
      rails new temp-rails-app --skip-javascript --skip-bundle --skip-spring --skip-test --skip-active-record
      rm -rf temp-rails-app/.git
    ))
    Bundler.with_unbundled_env do
      sh_in_dir(TEMP_RAILS_APP_PATH, %(
        gem update bundler
        bundle add shakapacker --path "#{GEM_ROOT}"
        FORCE=true bundle exec rails shakapacker:install
      ))
    end
  end

  after :all do
    Dir.chdir(SPEC_PATH)
    FileUtils.rm_rf(TEMP_RAILS_APP_PATH)
  end

  it "creates `config/shakapacker.yml`" do
    config_file_relative_path = "config/shakapacker.yml"
    actual_content = read(path_in_the_app(config_file_relative_path))
    expected_content = read(path_in_the_gem(config_file_relative_path))

    expect(actual_content).to eq expected_content
  end

  it "replaces package.json with template file" do
    actual_content = read(path_in_the_app("package.json"))

    expect(actual_content).to match /"name": "app",/
  end

  it "creates webpack config directory and its files" do
    expected_files = [
      "webpack.config.js"
    ]

    Dir.chdir(path_in_the_app("config/webpack")) do
      exisiting_files_in_config_webpack_dir = Dir.glob("*")
      expect(exisiting_files_in_config_webpack_dir).to eq expected_files
    end
  end

  it "adds binstubs" do
    expected_binstubs = []
    Dir.chdir(File.join(GEM_ROOT, "lib/install/bin")) do
      expected_binstubs = Dir.glob("bin/*")
    end

    Dir.chdir(File.join(TEMP_RAILS_APP_PATH, "bin")) do
      actual_binstubs = Dir.glob("*")
      expect(actual_binstubs).to include(*expected_binstubs)
    end
  end

  it "modifies .gitignore" do
    actual_content = read(path_in_the_app(".gitignore"))

    expect(actual_content).to match ".yarn-integrity"
  end

  it 'adds <%= javascript_pack_tag "application" %>' do
    actual_content = read(path_in_the_app("app/views/layouts/application.html.erb"))

    expect(actual_content).to match '<%= javascript_pack_tag "application" %>'
  end

  it "updates `bin/setup" do
    setup_file_content = read(path_in_the_app("bin/setup"))
    expect(setup_file_content).to match %r(^\s*system!\(['"]bin/yarn['"]\))
  end

  it "adds relevant shakapacker version in package.json depending on gem version," do
    npm_version = Shakapacker::Utils::VersionSyntaxConverter.new.rubygem_to_npm(Shakapacker::VERSION)

    actual_content = read(path_in_the_app("package.json"))

    expect(actual_content).to match /"shakapacker": "#{npm_version}",/
  end

  it "adds Shakapacker peer dependencies to package.json" do
    package_json_content_in_app = read(path_in_the_app("package.json"))

    expected_dependencies = %w(
      @babel/core
      @babel/plugin-transform-runtime
      @babel/preset-env
      @babel/runtime
      babel-loader
      compression-webpack-plugin
      terser-webpack-plugin
      webpack
      webpack-assets-manifest
      webpack-cli
      webpack-dev-server
      webpack-merge
    )

    expected_dependencies.each do |package|
      expect(package_json_content_in_app).to include package
    end
  end

  private
    def path_in_the_app(relative_path = nil)
      Pathname.new(File.join([TEMP_RAILS_APP_PATH, relative_path].compact))
    end

    def path_in_the_gem(relative_path = nil)
      Pathname.new(File.join([GEM_ROOT, "lib/install" , relative_path].compact))
    end

    def read(path)
      File.read(path)
    end

    def sh_in_dir(dir, *shell_commands)
      Shakapacker::Utils::Misc.sh_in_dir(dir, *shell_commands)
    end
end

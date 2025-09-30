require "pathname"
require "rake"
require "json"
require "shakapacker/utils/misc"
require "shakapacker/utils/version_syntax_converter"
require "package_json"
require_relative "../support/package_json_helpers"

GEM_ROOT = Pathname.new(File.expand_path("../../..", __FILE__))
SPEC_PATH = Pathname.new(File.expand_path("../", __FILE__))
BASE_RAILS_APP_PATH = SPEC_PATH.join("base-rails-app")
TEMP_RAILS_APP_PATH = SPEC_PATH.join("temp-rails-app")

describe "Generator" do
  before :all do
    # Don't use --skip-git because we want .gitignore file to exist in the project
    sh_in_dir({}, SPEC_PATH, %(
      rails new base-rails-app --skip-javascript --skip-bundle --skip-spring
      rm -rf base-rails-app/.git
    ))

    Bundler.with_unbundled_env do
      sh_in_dir({}, BASE_RAILS_APP_PATH, %(
        echo 'gem "concurrent-ruby", "1.3.4"' >> Gemfile
      ))

      if RUBY_VERSION.start_with?("2.")
        # Bundler's version compatible with Ruby 2 does not support "--path" switch
        # Overwriting "rack" version due to unless Rack::Handler::Puma.respond_to?(:config) in Capybara gem v3.39.2 or earlier.
        # Issue resolved in Capybara v3.40.0, but Ruby 2.7 support dropped; last compatible version is v3.39.2.
        # Ref: https://github.com/shakacode/shakapacker/issues/498
        sh_in_dir({}, BASE_RAILS_APP_PATH, %(
          echo 'gem "shakapacker", :path => "#{GEM_ROOT}"' >> Gemfile
          echo 'gem "rack", "< 3.0.0"' >> Gemfile
          bundle install
        ))
      else
        sh_in_dir({}, BASE_RAILS_APP_PATH, %(
          bundle add shakapacker --path "#{GEM_ROOT}"
        ))
      end
    end
  end

  after :all do
    Dir.chdir(SPEC_PATH)
    FileUtils.rm_rf(BASE_RAILS_APP_PATH)
  end

  describe "shakapacker:install" do
    # TODO: ideally "yarn_berry" should be here too, but it requires more complex setup
    NODE_PACKAGE_MANAGERS.reject { |fm| fm == "yarn_berry" }.each do |fallback_manager|
      context "when using package_json with #{fallback_manager} as the manager" do
        before :all do
          sh_opts = { fallback_manager: fallback_manager }

          sh_in_dir(sh_opts, SPEC_PATH, "cp -r '#{BASE_RAILS_APP_PATH}' '#{TEMP_RAILS_APP_PATH}'")

          Bundler.with_unbundled_env do
            # Preserve SHAKAPACKER_NPM_PACKAGE if set (for CI testing with local tarball)
            npm_package_env = ENV['SHAKAPACKER_NPM_PACKAGE'] ? "SHAKAPACKER_NPM_PACKAGE='#{ENV['SHAKAPACKER_NPM_PACKAGE']}' " : ""
            sh_in_dir(sh_opts, TEMP_RAILS_APP_PATH, "#{npm_package_env}SHAKAPACKER_ASSETS_BUNDLER=webpack USE_BABEL_PACKAGES=true FORCE=true bundle exec rails shakapacker:install")

            # Update package.json to use local shakapacker package
            # This ensures webpack can find the shakapacker/package.json file
            package_json_path = File.join(TEMP_RAILS_APP_PATH, "package.json")
            package_json = JSON.parse(File.read(package_json_path))

            package_manager = fallback_manager.split("_")[0]

            # Bun has issues with file: references, so use bun link instead
            if package_manager == "bun"
              # First link the package globally from the gem root
              sh_in_dir(sh_opts, GEM_ROOT, "bun link")
              # Then link it in the temp app
              sh_in_dir(sh_opts, TEMP_RAILS_APP_PATH, "bun link shakapacker")
            else
              # Update the shakapacker dependency to use the local path
              package_json["dependencies"]["shakapacker"] = "file:#{GEM_ROOT}"

              # Write the updated package.json
              File.write(package_json_path, JSON.pretty_generate(package_json))

              # Reinstall dependencies to pick up the local path
              case package_manager
              when "yarn"
                sh_in_dir(sh_opts, TEMP_RAILS_APP_PATH, "yarn install")
              when "npm"
                sh_in_dir(sh_opts, TEMP_RAILS_APP_PATH, "npm install")
              when "pnpm"
                # pnpm needs --no-frozen-lockfile to allow changes
                sh_in_dir(sh_opts, TEMP_RAILS_APP_PATH, "pnpm install --no-frozen-lockfile")
              end
            end
          end
        end

        after :all do
          Dir.chdir(SPEC_PATH)
          FileUtils.rm_rf(TEMP_RAILS_APP_PATH)
        end

        it "creates `config/shakapacker.yml` with babel transpiler when USE_BABEL_PACKAGES is set" do
          config_file_relative_path = "config/shakapacker.yml"
          actual_content = read(path_in_the_app(config_file_relative_path))
          expected_content = read(path_in_the_gem(config_file_relative_path))

          # When USE_BABEL_PACKAGES=true, the config should be updated to use babel
          expected_content_with_babel = expected_content.gsub("javascript_transpiler: 'swc'", "javascript_transpiler: 'babel'")

          expect(actual_content).to eq expected_content_with_babel
        end

        it "ensures the 'packageManager' field is set" do
          package_json = PackageJson.read(path_in_the_app)

          manager_name = fallback_manager.split("_")[0]

          expect(package_json.fetch("packageManager", "")).to match(/#{manager_name}@\d+\.\d+\.\d+/)
        end

        it "creates webpack config directory and its files" do
          expected_files = [
            "webpack.config.js"
          ]

          Dir.chdir(path_in_the_app("config/webpack")) do
            existing_files_in_config_webpack_dir = Dir.glob("*")
            expect(existing_files_in_config_webpack_dir).to eq expected_files
          end
        end

        it "adds binstubs" do
          expected_binstubs = []
          Dir.chdir(File.join(GEM_ROOT, "lib/install/bin")) do
            expected_binstubs = Dir.glob("*")
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

        it "updates `bin/setup`" do
          package_json = PackageJson.read(path_in_the_app)
          cmd = package_json.manager.native_install_command.join(" ")

          setup_file_content = read(path_in_the_app("bin/setup"))

          expect(setup_file_content).to match %r(^\s*system!\(['"]#{cmd}['"]\))
        end

        it "adds relevant shakapacker version in package.json depending on gem version" do
          package_json = PackageJson.read(path_in_the_app)
          actual_version = package_json.fetch("dependencies", {})["shakapacker"]

          # After we update the package.json to use the local package for testing,
          # the version will be a file path instead of a semver version
          # Note: bun uses `bun link` instead of file: references, so it won't modify package.json
          if fallback_manager.include?("bun")
            # For bun, the package.json is not modified, so check for the original semver version
            npm_version = Shakapacker::Utils::VersionSyntaxConverter.new.rubygem_to_npm(Shakapacker::VERSION)
            expect(actual_version).to eq(npm_version)
          elsif ENV["SHAKAPACKER_NPM_PACKAGE"]
            # In CI with SHAKAPACKER_NPM_PACKAGE, version will be a file path (tarball)
            expect(actual_version).to match(/^file:/)
          else
            expect(actual_version).to eq("file:#{GEM_ROOT}")
          end
        end

        it "adds Shakapacker peer dependencies to package.json" do
          package_json = PackageJson.read(path_in_the_app)
          actual_dependencies = package_json.fetch("dependencies", {}).keys

          # When USE_BABEL_PACKAGES=true, we install both Babel AND SWC packages
          expected_dependencies = %w(
            @babel/core
            @babel/plugin-transform-runtime
            @babel/preset-env
            @babel/runtime
            babel-loader
            @swc/core
            swc-loader
            compression-webpack-plugin
            terser-webpack-plugin
            webpack
            webpack-assets-manifest
            webpack-cli
            webpack-merge
          )

          expect(actual_dependencies).to include(*expected_dependencies)
        end

        it "adds Shakapacker peer dev dependencies to package.json" do
          package_json = PackageJson.read(path_in_the_app)
          actual_dev_dependencies = package_json.fetch("devDependencies", {}).keys

          expected_dev_dependencies = %w(
            webpack-dev-server
          )

          expect(actual_dev_dependencies).to include(*expected_dev_dependencies)
        end

        context "with a basic react app setup" do
          it "passes the test for rendering react component on the page" do
            sh_opts = { fallback_manager: fallback_manager }

            Bundler.with_unbundled_env do
              sh_in_dir(sh_opts, TEMP_RAILS_APP_PATH, "./bin/rails app:template LOCATION=../e2e_template/template.rb")
              # Compile assets before running tests using bin/shakapacker
              sh_in_dir(sh_opts, TEMP_RAILS_APP_PATH, "APP_ROOT=#{TEMP_RAILS_APP_PATH} NODE_ENV=test RAILS_ENV=test bin/shakapacker")
              expect(sh_in_dir(sh_opts, TEMP_RAILS_APP_PATH, "bundle exec rspec")).to be_truthy
            end
          end
        end
      end
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

    def sort_out_package_json(opts)
      ENV["PATH"] = "#{SPEC_PATH}/fake-bin:#{ENV["PATH"]}"

      ENV["SHAKAPACKER_EXPECTED_PACKAGE_MANGER"] = opts[:fallback_manager]
      ENV["PACKAGE_JSON_FALLBACK_MANAGER"] = opts[:fallback_manager]
    end

    def sh_in_dir(opts, dir, *shell_commands)
      sort_out_package_json(opts)
      Shakapacker::Utils::Misc.sh_in_dir(dir, *shell_commands)
    end
end

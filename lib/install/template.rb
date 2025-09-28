require "shakapacker/utils/misc"
require "shakapacker/utils/manager"
require "shakapacker/utils/version_syntax_converter"
require "package_json"
require "yaml"
require "json"

# Install Shakapacker

force_option = ENV["FORCE"] ? { force: true } : {}

# Initialize variables for use throughout the template
# Using instance variable to avoid method definition issues in Rails templates
@package_json ||= PackageJson.new
install_dir = File.expand_path(File.dirname(__FILE__))

# Detect what transpiler to use for package installation
# USE_BABEL_PACKAGES is for backward compatibility and only affects package installation
@install_babel_packages = ENV["USE_BABEL_PACKAGES"] == "true" || ENV["USE_BABEL_PACKAGES"] == "1"

# Detect if we have existing babel configuration files
# (but not based on USE_BABEL_PACKAGES which is just for package installation)
babel_config_exists = File.exist?(Rails.root.join(".babelrc")) ||
                      File.exist?(Rails.root.join("babel.config.js")) ||
                      File.exist?(Rails.root.join("babel.config.json")) ||
                      File.exist?(Rails.root.join(".babelrc.js"))

babel_in_package_json = false
package_json_path = Rails.root.join("package.json")
if File.exist?(package_json_path)
  begin
    pj_content = JSON.parse(File.read(package_json_path))
    babel_in_package_json = pj_content.key?("babel") ||
                           pj_content.dig("dependencies", "@babel/core") ||
                           pj_content.dig("devDependencies", "@babel/core") ||
                           pj_content.dig("dependencies", "babel-loader") ||
                           pj_content.dig("devDependencies", "babel-loader")
  rescue JSON::ParserError
    # If package.json is malformed, assume no babel
  end
end

@has_existing_babel = babel_config_exists || babel_in_package_json

# Read existing config if it exists
@existing_config = {}
config_path = Rails.root.join("config/shakapacker.yml")
if File.exist?(config_path)
  begin
    @existing_config = YAML.load_file(config_path) || {}
  rescue Psych::SyntaxError
    # Invalid YAML, use empty config
  end
end

# Determine transpiler for installation
if @install_babel_packages
  @detected_transpiler = "babel"
  say "📦 Installing Babel packages (USE_BABEL_PACKAGES is set)", :yellow
elsif ENV["JAVASCRIPT_TRANSPILER"]
  @detected_transpiler = ENV["JAVASCRIPT_TRANSPILER"]
  say "📦 Using #{@detected_transpiler} transpiler (JAVASCRIPT_TRANSPILER env var)", :blue
elsif @has_existing_babel
  @detected_transpiler = "babel"
  say "🔍 Detected existing Babel configuration - will install Babel packages", :yellow
elsif @existing_config["javascript_transpiler"]
  @detected_transpiler = @existing_config["javascript_transpiler"]
  say "📦 Using existing configured #{@detected_transpiler} transpiler", :blue
else
  @detected_transpiler = "swc"
  say "✨ Using SWC transpiler (20x faster than Babel)", :green
end

# Copy config file
copy_file "#{install_dir}/config/shakapacker.yml", "config/shakapacker.yml", force_option

# Note: We don't modify the config file - it has 'swc' as default.
# Inform users if there's a mismatch between installed packages and config
if @detected_transpiler == "babel" && !@has_existing_babel
  # This happens when USE_BABEL_PACKAGES is set but no existing babel config is found
  say "   📝 Note: Babel packages installed, but config defaults to 'swc'.", :yellow  
  say "   To use Babel, update javascript_transpiler to 'babel' in config/shakapacker.yml", :yellow
elsif @has_existing_babel && @detected_transpiler == "babel"
  # When we detect existing babel setup, suggest updating the config
  say "   📝 Babel detected. Update javascript_transpiler to 'babel' in config/shakapacker.yml", :yellow
end

say "Copying webpack core config"
directory "#{install_dir}/config/webpack", "config/webpack", force_option

if Dir.exist?(Shakapacker.config.source_path)
  say "The packs app source directory already exists"
else
  say "Creating packs app source directory"
  empty_directory "app/javascript/packs"
  copy_file "#{install_dir}/application.js", "app/javascript/packs/application.js"
end

apply "#{install_dir}/binstubs.rb"

git_ignore_path = Rails.root.join(".gitignore")
if File.exist?(git_ignore_path)
  append_to_file git_ignore_path do
    "\n"                   +
    "/public/packs\n"      +
    "/public/packs-test\n" +
    "/node_modules\n"      +
    "/yarn-error.log\n"    +
    "yarn-debug.log*\n"    +
    ".yarn-integrity\n"
  end
end

if (app_layout_path = Rails.root.join("app/views/layouts/application.html.erb")).exist?
  say "Add JavaScript include tag in application layout"
  insert_into_file app_layout_path.to_s, %(\n    <%= javascript_pack_tag "application" %>), before: /\s*<\/head>/
else
  say "Default application.html.erb is missing!", :red
  say %(        Add <%= javascript_pack_tag "application" %> within the <head> tag in your custom layout.)
end

# setup the package manager with default values
@package_json.merge! do |pj|
  package_manager = pj.fetch("packageManager") do
    "#{Shakapacker::Utils::Manager.guess_binary}@#{Shakapacker::Utils::Manager.guess_version}"
  end

  {
    "name" => "app",
    "private" => true,
    "version" => "0.1.0",
    "browserslist" => [
      "defaults"
    ],
    "packageManager" => package_manager
  }.merge(pj)
end

Shakapacker::Utils::Manager.error_unless_package_manager_is_obvious!

# Ensure there is `system!("bin/yarn")` command in `./bin/setup` file
if (setup_path = Rails.root.join("bin/setup")).exist?
  native_install_command = @package_json.manager.native_install_command.join(" ")

  say "Run #{native_install_command} during bin/setup"

  if File.read(setup_path).match? Regexp.escape("  # system('bin/yarn')\n")
    gsub_file(setup_path, "# system('bin/yarn')", "system!('#{native_install_command}')")
  else
    # Due to the inconsistency of quotation usage in Rails 7 compared to
    # earlier versions, we check both single and double quotations here.
    pattern = /system\(['"]bundle check['"]\) \|\| system!\(['"]bundle install['"]\)\n/

    string_to_add = <<-RUBY

  # Install JavaScript dependencies
  system!("#{native_install_command}")
    RUBY

    if File.read(setup_path).match? pattern
      insert_into_file(setup_path, string_to_add, after: pattern)
    else
      say <<~MSG, :red
        It seems your `bin/setup` file doesn't have the expected content.
        Please review the file and manually add `system!("#{native_install_command}")` before any
        other command that requires JavaScript dependencies being already installed.
      MSG
    end
  end
end

Dir.chdir(Rails.root) do
  npm_version = Shakapacker::Utils::VersionSyntaxConverter.new.rubygem_to_npm(Shakapacker::VERSION)
  say "Installing shakapacker@#{npm_version}"
  begin
    @package_json.manager.add!(["shakapacker@#{npm_version}"], type: :production)
  rescue PackageJson::Error
    say "Shakapacker installation failed 😭 See above for details.", :red
    exit 1
  end

  @package_json.merge! do |pj|
    if pj["dependencies"] && pj["dependencies"]["shakapacker"]
      {
        "dependencies" => pj["dependencies"].merge({
          # TODO: workaround for test suite - long-run need to actually account for diff pkg manager behaviour
          "shakapacker" => pj["dependencies"]["shakapacker"].delete_prefix("^")
        })
      }
    else
      pj
    end
  end

  # Inline fetch_peer_dependencies and fetch_common_dependencies
  peers = PackageJson.read(install_dir).fetch(ENV["SHAKAPACKER_BUNDLER"] || "webpack")
  common_deps = ENV["SKIP_COMMON_LOADERS"] ? {} : PackageJson.read(install_dir).fetch("common")
  peers = peers.merge(common_deps)

  # Add transpiler-specific dependencies based on detected/configured transpiler
  # Inline the logic here since methods can't be called before they're defined in Rails templates

  # Babel dependencies - only install if explicitly needed
  # @install_babel_packages is true when USE_BABEL_PACKAGES env var is set
  if @detected_transpiler == "babel"
    say "📦 Installing Babel dependencies", :yellow
    babel_deps = PackageJson.read(install_dir).fetch("babel")
    peers = peers.merge(babel_deps)
  end

  # SWC dependencies (pin to major version 1)
  if @detected_transpiler == "swc"
    say "📦 Installing SWC dependencies (20x faster than Babel)", :green
    swc_deps = { "@swc/core" => "^1.3.0", "swc-loader" => "^0.2.0" }
    peers = peers.merge(swc_deps)
  end

  # esbuild dependencies (pin to major version 0)
  if @detected_transpiler == "esbuild"
    say "📦 Installing esbuild dependencies", :blue
    esbuild_deps = { "esbuild" => "^0.24.0", "esbuild-loader" => "^4.0.0" }
    peers = peers.merge(esbuild_deps)
  end

  dev_dependency_packages = ["webpack-dev-server"]

  dependencies_to_add = []
  dev_dependencies_to_add = []

  peers.each do |(package, version)|
    major_version = version.split("||").last.match(/(\d+)/)[1]
    entry = "#{package}@#{major_version}"

    if dev_dependency_packages.include? package
      dev_dependencies_to_add << entry
    else
      dependencies_to_add << entry
    end
  end

  say "Adding shakapacker peerDependencies"
  begin
    @package_json.manager.add!(dependencies_to_add, type: :production)
  rescue PackageJson::Error
    say "Shakapacker installation failed 😭 See above for details.", :red
    exit 1
  end

  say "Installing webpack-dev-server for live reloading as a development dependency"
  begin
    @package_json.manager.add!(dev_dependencies_to_add, type: :dev)
  rescue PackageJson::Error
    say "Shakapacker installation failed 😭 See above for details.", :red
    exit 1
  end

  # Configure babel preset in package.json if using babel
  # We check the @detected_transpiler variable set at the beginning
  if @detected_transpiler == "babel"
    @package_json.merge! do |pj|
      babel = pj.fetch("babel", {})
      babel["presets"] ||= []
      unless babel["presets"].include?("./node_modules/shakapacker/package/babel/preset.js")
        babel["presets"].push("./node_modules/shakapacker/package/babel/preset.js")
      end
      { "babel" => babel }
    end
  end
end

# Helper methods defined at the end (Rails template convention)

def package_json
  @package_json
end

def add_dependencies(dependencies, type)
  @package_json.manager.add!(dependencies, type: type)
rescue PackageJson::Error
  say "Shakapacker installation failed 😭 See above for details.", :red
  exit 1
end

def fetch_peer_dependencies
  PackageJson.read("#{__dir__}").fetch(ENV["SHAKAPACKER_BUNDLER"] || "webpack")
end

def fetch_common_dependencies
  ENV["SKIP_COMMON_LOADERS"] ? {} : PackageJson.read("#{__dir__}").fetch("common")
end

# Detect if project already uses babel
def detect_existing_babel_usage
  # Check for babel config files
  babel_config_exists = File.exist?(Rails.root.join(".babelrc")) ||
                        File.exist?(Rails.root.join("babel.config.js")) ||
                        File.exist?(Rails.root.join("babel.config.json")) ||
                        File.exist?(Rails.root.join(".babelrc.js"))

  # Check for babel in package.json
  babel_in_package = false
  package_json_path = Rails.root.join("package.json")
  if File.exist?(package_json_path)
    begin
      pj_content = JSON.parse(File.read(package_json_path))
      babel_in_package = pj_content.key?("babel") ||
                        pj_content.dig("dependencies", "@babel/core") ||
                        pj_content.dig("devDependencies", "@babel/core") ||
                        pj_content.dig("dependencies", "babel-loader") ||
                        pj_content.dig("devDependencies", "babel-loader")
    rescue JSON::ParserError
      # If package.json is malformed, assume no babel
    end
  end

  babel_config_exists || babel_in_package
end

# Note: The determine_javascript_transpiler and fetch_*_dependencies methods
# have been inlined above where they're used because Rails templates
# can't call methods before they're defined

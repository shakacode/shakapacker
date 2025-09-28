require "shakapacker/utils/misc"
require "shakapacker/utils/manager"
require "shakapacker/utils/version_syntax_converter"
require "package_json"
require "yaml"
require "json"

# Install Shakapacker

force_option = ENV["FORCE"] ? { force: true } : {}

# First detect what transpiler to use
@detected_transpiler = nil

# Check for existing babel configuration
has_babel_config = File.exist?(Rails.root.join(".babelrc")) || 
                   File.exist?(Rails.root.join("babel.config.js")) || 
                   File.exist?(Rails.root.join("babel.config.json")) ||
                   File.exist?(Rails.root.join(".babelrc.js"))

has_babel_in_package_json = false
package_json_path = Rails.root.join("package.json")
if File.exist?(package_json_path)
  begin
    pj_content = JSON.parse(File.read(package_json_path))
    has_babel_in_package_json = pj_content.key?("babel") || 
                                pj_content.dig("dependencies", "@babel/core") ||
                                pj_content.dig("devDependencies", "@babel/core") ||
                                pj_content.dig("dependencies", "babel-loader") ||
                                pj_content.dig("devDependencies", "babel-loader")
  rescue JSON::ParserError
    # If package.json is malformed, assume no babel
  end
end

if has_babel_config || has_babel_in_package_json
  @detected_transpiler = "babel"
  say "🔍 Detected existing Babel configuration - will configure Shakapacker to use Babel", :yellow
else
  @detected_transpiler = ENV["JAVASCRIPT_TRANSPILER"] || "swc"
end

# Copy config file
copy_file "#{__dir__}/config/shakapacker.yml", "config/shakapacker.yml", force_option

# Update the config file with the detected transpiler
if File.exist?("config/shakapacker.yml")
  config_content = File.read("config/shakapacker.yml")
  # Replace the default transpiler setting with the detected one
  if @detected_transpiler == "babel"
    config_content.gsub!("javascript_transpiler: 'swc'", "javascript_transpiler: 'babel'")
    File.write("config/shakapacker.yml", config_content)
    say "   Configured javascript_transpiler: 'babel' in config/shakapacker.yml"
  elsif @detected_transpiler == "swc"
    # Already set to swc by default, no change needed
    say "   Using SWC transpiler (20x faster than Babel)", :green
  end
end

say "Copying webpack core config"
directory "#{__dir__}/config/webpack", "config/webpack", force_option

if Dir.exist?(Shakapacker.config.source_path)
  say "The packs app source directory already exists"
else
  say "Creating packs app source directory"
  empty_directory "app/javascript/packs"
  copy_file "#{__dir__}/application.js", "app/javascript/packs/application.js"
end

apply "#{__dir__}/binstubs.rb"

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
package_json.merge! do |pj|
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
  native_install_command = package_json.manager.native_install_command.join(" ")

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
  add_dependencies(["shakapacker@#{npm_version}"], :production)

  package_json.merge! do |pj|
    {
      "dependencies" => pj["dependencies"].merge({
        # TODO: workaround for test suite - long-run need to actually account for diff pkg manager behaviour
        "shakapacker" => pj["dependencies"]["shakapacker"].delete_prefix("^")
      })
    }
  end

  peers = fetch_peer_dependencies
  peers = peers.merge(fetch_common_dependencies)
  peers = peers.merge(fetch_babel_dependencies)
  peers = peers.merge(fetch_swc_dependencies)
  peers = peers.merge(fetch_esbuild_dependencies)

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
  add_dependencies(dependencies_to_add, :production)

  say "Installing webpack-dev-server for live reloading as a development dependency"
  add_dependencies(dev_dependencies_to_add, :dev)
  
  # Configure babel preset in package.json if using babel
  if determine_javascript_transpiler == "babel"
    package_json.merge! do |pj|
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
  @package_json ||= PackageJson.new
end

def add_dependencies(dependencies, type)
  package_json.manager.add!(dependencies, type: type)
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
  has_babel_config = File.exist?(Rails.root.join(".babelrc")) || 
                     File.exist?(Rails.root.join("babel.config.js")) || 
                     File.exist?(Rails.root.join("babel.config.json")) ||
                     File.exist?(Rails.root.join(".babelrc.js"))
  
  # Check for babel in package.json
  has_babel_in_package_json = false
  package_json_path = Rails.root.join("package.json")
  if File.exist?(package_json_path)
    begin
      pj_content = JSON.parse(File.read(package_json_path))
      has_babel_in_package_json = pj_content.key?("babel") || 
                                  pj_content.dig("dependencies", "@babel/core") ||
                                  pj_content.dig("devDependencies", "@babel/core") ||
                                  pj_content.dig("dependencies", "babel-loader") ||
                                  pj_content.dig("devDependencies", "babel-loader")
    rescue JSON::ParserError
      # If package.json is malformed, assume no babel
    end
  end
  
  has_babel_config || has_babel_in_package_json
end

# Determine which JavaScript transpiler to use (cached)
def determine_javascript_transpiler
  @javascript_transpiler ||= begin
    # 1. Check explicit environment variable
    if ENV["JAVASCRIPT_TRANSPILER"]
      say "Using #{ENV["JAVASCRIPT_TRANSPILER"]} transpiler (from JAVASCRIPT_TRANSPILER env var)"
      ENV["JAVASCRIPT_TRANSPILER"]
    # 2. Check existing shakapacker.yml config
    elsif File.exist?(Rails.root.join("config/shakapacker.yml"))
      config = YAML.load_file(Rails.root.join("config/shakapacker.yml"))
      transpiler = config.dig("default", "javascript_transpiler") || 
                   config.dig("production", "javascript_transpiler")
      if transpiler
        say "Using #{transpiler} transpiler (from config/shakapacker.yml)"
        transpiler
      elsif detect_existing_babel_usage
        # Config exists but no transpiler set, check for babel
        say "🔍 Detected existing Babel configuration", :yellow
        say "   Keeping Babel as your JavaScript transpiler for compatibility"
        say "   💡 To migrate to SWC later (20x faster): Set javascript_transpiler: 'swc' in config/shakapacker.yml"
        "babel"
      else
        # Config exists but no transpiler set, no babel detected
        say "✨ Using SWC as JavaScript transpiler (20x faster than Babel)", :green
        say "   • Zero configuration required"
        say "   • Full TypeScript and JSX support"
        "swc"
      end
    # 3. For new projects, detect babel usage
    elsif detect_existing_babel_usage
      say "🔍 Detected existing Babel configuration", :yellow
      say "   Keeping Babel as your JavaScript transpiler for compatibility"
      say "   💡 To migrate to SWC later (20x faster): Set javascript_transpiler: 'swc' in config/shakapacker.yml"
      "babel"
    # 4. Default to SWC for new projects
    else
      say "✨ Using SWC as JavaScript transpiler (20x faster than Babel)", :green
      say "   • Zero configuration required"
      say "   • Full TypeScript and JSX support"
      "swc"
    end
  end
end

def fetch_babel_dependencies
  javascript_transpiler = determine_javascript_transpiler
  
  # Support legacy USE_BABEL_PACKAGES env var for backward compatibility
  should_install_babel = ENV["USE_BABEL_PACKAGES"] || javascript_transpiler == "babel"
  
  if should_install_babel
    say "📦 Installing Babel dependencies", :yellow
    PackageJson.read("#{__dir__}").fetch("babel")
  else
    {}
  end
end

def fetch_swc_dependencies
  javascript_transpiler = determine_javascript_transpiler
  
  if javascript_transpiler == "swc"
    say "📦 Installing SWC dependencies (20x faster than Babel)", :green
    { "@swc/core" => "latest", "swc-loader" => "latest" }
  else
    {}
  end
end

def fetch_esbuild_dependencies
  javascript_transpiler = determine_javascript_transpiler
  
  if javascript_transpiler == "esbuild"
    say "📦 Installing esbuild dependencies", :blue
    { "esbuild" => "latest", "esbuild-loader" => "latest" }
  else
    {}
  end
end
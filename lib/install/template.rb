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

# Package installation strategy:
# 1. Always install packages for the transpiler in the config file (defaults to swc)
# 2. Additionally install babel packages if USE_BABEL_PACKAGES is set (backward compatibility)
# This ensures runtime can use the configured transpiler while maintaining compatibility

# Check if USE_BABEL_PACKAGES is set for backward compatibility
@install_babel_packages = ENV["USE_BABEL_PACKAGES"] == "true" || ENV["USE_BABEL_PACKAGES"] == "1"

# Determine the configured transpiler (what the config file will use at runtime)
# Since we're copying the default config which has 'swc', that's our default
@config_transpiler = ENV["JAVASCRIPT_TRANSPILER"] || "swc"

if @install_babel_packages && @config_transpiler == "swc"
  say "📦 Installing Babel packages (USE_BABEL_PACKAGES is set)", :yellow
  say "✨ Also installing SWC packages (config default)", :green
elsif @install_babel_packages && @config_transpiler == "babel"
  say "📦 Installing Babel packages", :yellow
elsif @config_transpiler == "swc"
  say "✨ Installing SWC packages (20x faster than Babel)", :green
elsif @config_transpiler == "esbuild"
  say "📦 Installing esbuild packages", :blue
elsif @config_transpiler == "babel"
  say "📦 Installing Babel packages", :yellow
end

# Copy config file (always copies as-is, never modified)
copy_file "#{install_dir}/config/shakapacker.yml", "config/shakapacker.yml", force_option

# Inform about config if there's a mismatch
if @install_babel_packages && @config_transpiler == "swc"
  say "   📝 Note: Babel packages installed for compatibility, but config uses SWC", :yellow
  say "   To use Babel at runtime, set javascript_transpiler to 'babel' in config/shakapacker.yml", :yellow
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

  # Install babel dependencies if USE_BABEL_PACKAGES is set (backward compatibility)
  if @install_babel_packages
    babel_deps = PackageJson.read(install_dir).fetch("babel")
    peers = peers.merge(babel_deps)
  end

  # Always install the transpiler packages that match the config file
  # This ensures the runtime can use the configured transpiler
  case @config_transpiler
  when "babel"
    # Only install babel if not already installed via USE_BABEL_PACKAGES
    if !@install_babel_packages
      babel_deps = PackageJson.read(install_dir).fetch("babel")
      peers = peers.merge(babel_deps)
    end
  when "swc"
    swc_deps = { "@swc/core" => "^1.3.0", "swc-loader" => "^0.2.0" }
    peers = peers.merge(swc_deps)
  when "esbuild"
    esbuild_deps = { "esbuild" => "^0.24.0", "esbuild-loader" => "^4.0.0" }
    peers = peers.merge(esbuild_deps)
  end

  dev_dependency_packages = ["webpack-dev-server"]

  dependencies_to_add = []
  dev_dependencies_to_add = []

  peers.each do |(package, version)|
    # Handle versions like "^1.3.0" or ">= 4 || 5" 
    if version.start_with?("^") || version.start_with?("~") || version.match?(/^\d+\.\d+/)
      # Already has proper version format, use as-is
      entry = "#{package}@#{version}"
    else
      # Extract major version from complex version strings like ">= 4 || 5"
      major_version = version.split("||").last.match(/(\d+)/)[1]
      entry = "#{package}@#{major_version}"
    end

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

  # Configure babel preset in package.json if babel packages are installed
  if @install_babel_packages || @config_transpiler == "babel"
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

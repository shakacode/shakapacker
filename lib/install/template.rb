require "shakapacker/utils/misc"
require "shakapacker/utils/manager"
require "shakapacker/utils/version_syntax_converter"
require "shakapacker/install/env"
require "package_json"
require "yaml"
require "json"

# Install Shakapacker

@conflict_option = Shakapacker::Install::Env.conflict_option

# Initialize variables for use throughout the template
# Using instance variable to avoid method definition issues in Rails templates
@package_json ||= PackageJson.new
install_dir = File.expand_path(File.dirname(__FILE__))

# Read the existing app's bundler (if any) before copy_file can overwrite it, so a
# re-install can default to that bundler instead of silently switching it.
config_path = Rails.root.join("config/shakapacker.yml")
shakapacker_config_preexisting = config_path.exist?
existing_assets_bundler =
  File.read(config_path)[/assets_bundler:\s*"([^"]+)"/, 1] if shakapacker_config_preexisting

# New installs default to rspack; an existing app keeps its current bundler on a
# re-install unless overridden by the env var/argument or a FORCE overwrite (see
# Env.resolve_assets_bundler for the precedence rules). The bundled shakapacker.yml
# ships "webpack" for backward compatibility and is rewritten below when the chosen
# bundler differs.
assets_bundler = Shakapacker::Install::Env.resolve_assets_bundler(
  env_value: ENV["SHAKAPACKER_ASSETS_BUNDLER"],
  existing_bundler: existing_assets_bundler,
  force: @conflict_option[:force]
)

# Fail fast on a misspelled SHAKAPACKER_ASSETS_BUNDLER instead of failing later
# with a confusing missing-config-directory or peer-lookup error.
unless Shakapacker::Install::Env::VALID_BUNDLERS.include?(assets_bundler)
  say "❌ Unknown bundler '#{assets_bundler}'. Set SHAKAPACKER_ASSETS_BUNDLER to one of: #{Shakapacker::Install::Env::VALID_BUNDLERS.join(", ")}.", :red
  exit 1
end

# Installation strategy:
# - USE_BABEL_PACKAGES installs both babel AND swc for compatibility
# - Otherwise install only the specified transpiler
if Shakapacker::Install::Env.truthy_env?("USE_BABEL_PACKAGES")
  @transpiler_to_install = "babel"
  @install_swc_compat_packages = true
  say "📦 Installing Babel packages (USE_BABEL_PACKAGES is set)", :yellow
  say "✨ Also installing SWC packages for default config compatibility", :green
elsif ENV["JAVASCRIPT_TRANSPILER"]
  @transpiler_to_install = ENV["JAVASCRIPT_TRANSPILER"]
  @install_swc_compat_packages = false
  say "📦 Installing #{@transpiler_to_install} packages", :blue
else
  # Default to swc (matches the default in shakapacker.yml)
  @transpiler_to_install = "swc"
  @install_swc_compat_packages = false
  say "✨ Installing SWC packages (20x faster than Babel)", :green
end

# Copy config file
copy_file "#{install_dir}/config/shakapacker.yml", "config/shakapacker.yml", @conflict_option

# Update config to match the selected transpiler
# Skip modification only when SKIP mode preserved a pre-existing user file
if Shakapacker::Install::Env.update_transpiler_config?(
  transpiler_to_install: @transpiler_to_install,
  conflict_option: @conflict_option,
  config_preexisting: shakapacker_config_preexisting
)
  gsub_file "config/shakapacker.yml", 'javascript_transpiler: "swc"', "javascript_transpiler: \"#{@transpiler_to_install}\""
  # Unlike the bundler rewrite below (which only runs on installer-owned files and
  # aborts on a miss), this can also run against a pre-existing user config whose
  # transpiler line may legitimately differ from the shipped "swc" literal. A no-op
  # there is not an error, so only claim success when the value actually landed.
  if File.read(config_path).include?("javascript_transpiler: \"#{@transpiler_to_install}\"")
    say "   📝 Updated config/shakapacker.yml to use #{@transpiler_to_install} transpiler", :green
  end
end

# Update config to match the selected bundler (see update_assets_bundler_config?
# for when the installer rewrites the shipped "webpack" default vs. preserves an
# existing config).
if Shakapacker::Install::Env.update_assets_bundler_config?(
  assets_bundler_to_install: assets_bundler,
  conflict_option: @conflict_option,
  config_preexisting: shakapacker_config_preexisting
)
  gsub_file "config/shakapacker.yml", 'assets_bundler: "webpack"', "assets_bundler: \"#{assets_bundler}\""
  # gsub_file silently no-ops if the shipped literal is ever reformatted, so verify
  # the value landed. Abort rather than continue, since the installer is about to set
  # up the chosen bundler's dependencies and config, and a mismatched bundler value
  # would produce a broken install. This runs before any dependencies are installed.
  if File.read(config_path).include?("assets_bundler: \"#{assets_bundler}\"")
    say "   📝 Updated config/shakapacker.yml to use #{assets_bundler} bundler", :green
  else
    say "❌ Could not set assets_bundler to \"#{assets_bundler}\" in config/shakapacker.yml " \
        "— the expected 'assets_bundler: \"webpack\"' line was not found. Aborting so the " \
        "install doesn't proceed with a mismatched bundler config.", :red
    exit 1
  end
else
  # The bundler config was left as-is (an existing app's config is preserved unless
  # FORCE overwrites it). Report the value present, and warn if it differs from the
  # bundler whose dependencies/config are being installed — usually when a bundler is
  # requested explicitly (env var or task argument) against a preserved config, but
  # also when a preserved config holds an unrecognized bundler and resolve_assets_bundler
  # falls back to rspack. Either case would otherwise be a silent mismatch. Only act
  # when we can read the value back — never guess, or the message could contradict the file.
  retained_bundler = File.read(config_path)[/assets_bundler:\s*"([^"]+)"/, 1]
  if retained_bundler && retained_bundler != assets_bundler
    say "⚠️  Installing #{assets_bundler} dependencies, but config/shakapacker.yml keeps " \
        "assets_bundler: \"#{retained_bundler}\". To switch an existing app's bundler, run " \
        "`bin/rake shakapacker:switch_bundler #{assets_bundler} -- --install-deps`, " \
        "or re-run the installer with FORCE=true to overwrite the config.", :yellow
  elsif retained_bundler
    say "   📝 Keeping assets_bundler: \"#{retained_bundler}\" in config/shakapacker.yml", :green
  end
end

# Detect TypeScript usage
# Auto-detect from tsconfig.json or explicit via SHAKAPACKER_USE_TYPESCRIPT env var
@use_typescript = File.exist?(Rails.root.join("tsconfig.json")) ||
  Shakapacker::Install::Env.truthy_env?("SHAKAPACKER_USE_TYPESCRIPT")
config_extension = @use_typescript ? "ts" : "js"

say "Copying #{assets_bundler} core config (#{config_extension.upcase})"
config_file = "#{assets_bundler}.config.#{config_extension}"
source_config = "#{install_dir}/config/#{assets_bundler}/#{config_file}"
dest_config = "config/#{assets_bundler}/#{config_file}"

empty_directory "config/#{assets_bundler}"
copy_file source_config, dest_config, @conflict_option

if @use_typescript
  say "   ✨ Using TypeScript config for enhanced type safety", :green
end

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
  shakapacker_dependency_value = nil

  # In CI, use the pre-packed tarball if available
  if ENV["SHAKAPACKER_NPM_PACKAGE"]
    package_path = ENV["SHAKAPACKER_NPM_PACKAGE"]

    # Validate package path to prevent directory traversal and invalid file types
    begin
      # Resolve to absolute path
      absolute_path = File.expand_path(package_path)

      # Reject paths containing directory traversal
      if package_path.include?("..") || absolute_path.include?("..")
        say "❌ Security Error: Package path contains directory traversal: #{package_path}", :red
        exit 1
      end

      # Ensure filename ends with .tgz or .tar.gz
      unless absolute_path.end_with?(".tgz", ".tar.gz")
        say "❌ Security Error: Package must be a .tgz or .tar.gz file: #{package_path}", :red
        exit 1
      end

      # Check existence only after validation
      if File.exist?(absolute_path)
        say "📦 Installing shakapacker from local package: #{absolute_path}", :cyan
        begin
          @package_json.manager.add!([absolute_path], type: :production)
          shakapacker_dependency_value = absolute_path
        rescue PackageJson::Error
          say "Shakapacker installation failed 😭 See above for details.", :red
          exit 1
        end
      else
        say "⚠️  SHAKAPACKER_NPM_PACKAGE set but file not found: #{absolute_path}", :yellow
        say "Falling back to npm registry...", :yellow
        begin
          @package_json.manager.add!(["shakapacker@#{npm_version}"], type: :production)
          shakapacker_dependency_value = npm_version
        rescue PackageJson::Error
          say "Shakapacker installation failed 😭 See above for details.", :red
          exit 1
        end
      end
    rescue => e
      say "❌ Error validating package path: #{e.message}", :red
      exit 1
    end
  else
    say "Installing shakapacker@#{npm_version}"
    begin
      @package_json.manager.add!(["shakapacker@#{npm_version}"], type: :production)
      shakapacker_dependency_value = npm_version
    rescue PackageJson::Error
      say "Shakapacker installation failed 😭 See above for details.", :red
      exit 1
    end
  end

  @package_json.merge! do |pj|
    if pj["dependencies"] && pj["dependencies"]["shakapacker"]
      {
        "dependencies" => pj["dependencies"].merge({
          # Keep package.json aligned with the exact source/version this installer requested.
          "shakapacker" => shakapacker_dependency_value || pj["dependencies"]["shakapacker"].delete_prefix("^")
        })
      }
    else
      pj
    end
  end

  # Inline fetch_peer_dependencies and fetch_common_dependencies
  peers = PackageJson.read(install_dir).fetch(assets_bundler)
  common_deps = Shakapacker::Install::Env.truthy_env?("SKIP_COMMON_LOADERS") ? {} : PackageJson.read(install_dir).fetch("common")
  peers = common_deps.merge(peers)
  if assets_bundler == "rspack" && common_deps.key?("css-loader")
    peers["css-loader"] = "^7.1.4"
  end

  # Add transpiler-specific dependencies based on detected/configured transpiler
  # Inline the logic here since methods can't be called before they're defined in Rails templates

  # Install transpiler-specific dependencies
  if @transpiler_to_install == "babel"
    # Install babel packages
    babel_deps = PackageJson.read(install_dir).fetch("babel")
    peers = peers.merge(babel_deps)

    # Also install SWC only when USE_BABEL_PACKAGES requested compatibility mode.
    if @install_swc_compat_packages
      swc_deps = PackageJson.read(install_dir).fetch("swc")
      peers = peers.merge(swc_deps)

      say "ℹ️  Installing both Babel and SWC packages for compatibility:", :blue
      say "   - Babel packages are installed as requested via USE_BABEL_PACKAGES", :blue
      say "   - SWC packages are also installed to ensure the default config works", :blue
      say "   - Your actual transpiler will be determined by your shakapacker.yml configuration", :blue
    end
  elsif @transpiler_to_install == "swc"
    swc_deps = PackageJson.read(install_dir).fetch("swc")
    peers = peers.merge(swc_deps)
  elsif @transpiler_to_install == "esbuild"
    esbuild_deps = PackageJson.read(install_dir).fetch("esbuild")
    peers = peers.merge(esbuild_deps)
  end

  # Lists both dev servers for classification only; just the one matching the chosen
  # bundler appears in `peers`, so only that package is actually installed.
  dev_dependency_packages = ["webpack-dev-server", "@rspack/dev-server"]

  dependencies_to_add = []
  dev_dependencies_to_add = []

  peers.each do |(package, version)|
    # constraints conventionally are from oldest to latest
    constraints = version.split("||").map(&:strip)
    selected_version = constraints.last

    if package == "webpack-cli" && constraints.length > 1
      # Keep installer defaults compatible with Node.js >= 20.0.0.
      # webpack-cli v7 requires Node >= 20.9.0, so default to the latest v6 range.
      selected_version = constraints.find { |constraint| constraint.start_with?("^6.") } || selected_version
      say "   ℹ️  Defaulting to webpack-cli #{selected_version} for broad Node.js compatibility.", :blue
      say "   ℹ️  If you're on Node >= 20.9.0, you can upgrade to webpack-cli ^7.0.0 manually.", :blue
    end

    entry = "#{package}@#{selected_version}"

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

  if dev_dependencies_to_add.any?
    # Strip the trailing @version, keeping the package name; the regex drops only
    # the last @-segment so scoped names (e.g. @rspack/dev-server) survive.
    dev_dependency_names = dev_dependencies_to_add.map { |entry| entry.sub(/@[^@]+\z/, "") }
    say "Installing development dependencies: #{dev_dependency_names.join(", ")}"
    begin
      @package_json.manager.add!(dev_dependencies_to_add, type: :dev)
    rescue PackageJson::Error
      say "Shakapacker installation failed 😭 See above for details.", :red
      exit 1
    end
  end

  # Configure babel preset in package.json if babel is being used
  if @transpiler_to_install == "babel"
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

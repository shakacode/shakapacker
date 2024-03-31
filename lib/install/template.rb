require "shakapacker/utils/misc"
require "shakapacker/utils/manager"
require "shakapacker/utils/version_syntax_converter"
require "package_json"

# Install Shakapacker

force_option = ENV["FORCE"] ? { force: true } : {}

copy_file "#{__dir__}/config/shakapacker.yml", "config/shakapacker.yml", force_option
remove_file "#{__dir__}/package.json" if force_option[:force]

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

def package_json
  @package_json ||= PackageJson.new
end

# setup the package manager with default values
package_json.merge! do |pj|
  babel = pj.fetch("babel", {})

  babel["presets"] ||= []
  babel["presets"].push("./node_modules/shakapacker/package/babel/preset.js")

  package_manager = pj.fetch("packageManager") do
    "#{Shakapacker::Utils::Manager.guess_binary}@#{Shakapacker::Utils::Manager.guess_version}"
  end

  {
    "name" => "app",
    "private" => true,
    "version" => "0.1.0",
    "babel" => babel,
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

def add_dependencies(dependencies, type)
  package_json.manager.add!(dependencies, type: type)
rescue PackageJson::Error
  say "Shakapacker installation failed 😭 See above for details.", :red
  exit 1
end

def fetch_peer_dependencies
  PackageJson.read("#{__dir__}/../../").fetch("peerDependencies")
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
  dev_dependency_packages = ["webpack-dev-server"]

  dependencies_to_add = []
  dev_dependencies_to_add = []

  peers.each do |(package, version)|
    major_version = version.match(/(\d+)/)[1]
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
end

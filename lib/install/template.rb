# Install Shakapacker
copy_file "#{__dir__}/config/shakapacker.yml", "config/shakapacker.yml"
copy_file "#{__dir__}/package.json", "package.json"

say "Copying webpack core config"
directory "#{__dir__}/config/webpack", "config/webpack"

if Dir.exist?(Shakapacker.config.source_path)
  say "The packs app source directory already exists"
else
  say "Creating packs app source directory"
  empty_directory "app/javascript"
  copy_file "#{__dir__}/application.js", "app/javascript/application.js"
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

# Ensure there is `system!("bin/yarn")` command in `./bin/setup` file
if (setup_path = Rails.root.join("bin/setup")).exist?
  say "Run bin/yarn during bin/setup"

  if File.read(setup_path).match? Regexp.escape("  # system('bin/yarn')\n")
    gsub_file(setup_path, "# system('bin/yarn')", "system!('bin/yarn')")
  else
    # Due to the inconsistency of quotation usage in Rails 7 compared to
    # earlier versions, we check both single and double quotations here.
    pattern = /system\(['"]bundle check['"]\) \|\| system!\(['"]bundle install['"]\)\n/

    string_to_add = <<-RUBY

  # Install JavaScript dependencies
  system!("bin/yarn")
RUBY

    if File.read(setup_path).match? pattern
      insert_into_file(setup_path, string_to_add, after: pattern)
    else
      say <<~MSG, :red
        It seems your `bin/setup` file doesn't have the expected content.
        Please review the file and manually add `system!("bin/yarn")` before any
        other command that requires JavaScript dependencies being already installed.
      MSG
    end
  end
end

results = []

Dir.chdir(Rails.root) do
  if Shakapacker::VERSION.match?(/^[0-9]+\.[0-9]+\.[0-9]+$/)
    say "Installing shakapacker@#{Shakapacker::VERSION}"
    results << run("yarn add shakapacker@#{Shakapacker::VERSION} --exact")
  else
    say "Installing shakapacker@next"
    results << run("yarn add shakapacker@next --exact")
  end

  package_json = File.read("#{__dir__}/../../package.json")
  peers = JSON.parse(package_json)["peerDependencies"]
  peers_to_add = peers.reduce([]) do |result, (package, version)|
    major_version = version.match(/(\d+)/)[1]
    result << "#{package}@#{major_version}"
  end.join(" ")

  say "Adding shakapacker peerDependencies"
  results << run("yarn add #{peers_to_add}")

  say "Installing webpack-dev-server for live reloading as a development dependency"
  results << run("yarn add --dev webpack-dev-server")
end

unless results.all?
  say "Shakapacker installation failed 😭 See above for details.", :red
  exit 1
end

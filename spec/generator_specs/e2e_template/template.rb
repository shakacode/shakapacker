# TODO: replace with standard "require" call once gem is published
def require_package_json_gem
  require "bundler/inline"

  gemfile { gem "package_json", github: "G-Rath/package_json" }

  puts "using package_json v#{PackageJson::VERSION}"
end

require_package_json_gem

package_json = PackageJson.new

# install react
package_json.manager.add(["react", "react-dom", "@babel/preset-react"])

# update webpack presets for react
package_json.merge! do |pj|
  presets = pj.fetch("presets", [])

  presets.unshift("@babel/preset-react")

  { "presets" => presets }
end

# install rspec-rails
system("bundle add rspec-rails --group development,test")
system("bundle exec rails g rspec:install")

# copy files
directory(
  Rails.root.join("../e2e_template/files"),
  Rails.root,
  force: true
)

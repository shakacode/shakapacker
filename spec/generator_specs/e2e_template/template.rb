require "shakapacker/utils/misc"

require "package_json"

package_json = PackageJson.new

# install react
# Pin @babel/preset-react to v7: the generated app uses @babel/core ^7, but
# @babel/preset-react@8 requires @babel/core ^8, so an unpinned add resolves to
# v8 and fails with npm ERESOLVE (leaving react/react-dom uninstalled).
package_json.manager.add(["react", "react-dom", "@babel/preset-react@^7"])

# update webpack presets for react
package_json.merge! do |pj|
  babel = pj.fetch("babel", {})

  babel["presets"] ||= []
  babel["presets"].unshift("@babel/preset-react")

  { "babel" => babel }
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

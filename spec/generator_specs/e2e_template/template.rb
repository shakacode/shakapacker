require "shakapacker/utils/misc"

require "package_json"

package_json = PackageJson.new

# install react
# preset-react 8 peers on @babel/core 8; pin to v7 to match the generated app's @babel/core.
package_json.manager.add([
  "react@^18.3.1",
  "react-dom@^18.3.1",
  "@babel/preset-react@^7.18.6"
])

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

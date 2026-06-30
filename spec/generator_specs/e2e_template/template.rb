require "shakapacker/utils/misc"

require "package_json"

package_json = PackageJson.new

# install react
# react-dom 19 is not compatible with this generated app config.
# preset-react 8 peers on @babel/core 8, so keep the generated app on React 18 and preset-react 7.
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

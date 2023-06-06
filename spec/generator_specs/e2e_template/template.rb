# install react
system("yarn add react react-dom @babel/preset-react")

# update webpack presets for react
package_json_path = Rails.root.join("./package.json")
insert_into_file(
  package_json_path,
  %(      "@babel/preset-react",\n),
  after: /"presets": \[\n/
)

# install rspec-rails
system("bundle add rspec-rails --group development,test")
system("bundle exec rails g rspec:install")

# copy files
directory(
  Rails.root.join("../e2e_template/files"),
  Rails.root,
  force: true
)

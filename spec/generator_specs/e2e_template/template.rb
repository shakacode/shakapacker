require "shakapacker/utils/misc"

if Shakapacker::Utils::Misc.use_package_json_gem
  Shakapacker::Utils::Misc.require_package_json_gem

  package_json = PackageJson.new

  # install react
  package_json.manager.add(["react", "react-dom", "@babel/preset-react"])

  # update webpack presets for react
  package_json.merge! do |pj|
    babel = pj.fetch("babel", {})

    babel["presets"] ||= []
    babel["presets"].unshift("@babel/preset-react")

    { "babel" => babel }
  end
else
  # install react
  system("yarn add react react-dom @babel/preset-react")

  # update webpack presets for react
  package_json_path = Rails.root.join("./package.json")
  insert_into_file(
    package_json_path,
    %(      "@babel/preset-react",\n),
    after: /"presets": \[\n/
  )
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

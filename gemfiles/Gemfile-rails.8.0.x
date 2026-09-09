source "https://rubygems.org"

git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec path: "../"

gem "rails", '~>8.0.0'
gem "rake", ">= 11.1"
gem "rack-proxy", require: false
# json 3 removes the `quirks_mode` keyword passed by supported ActiveSupport versions.
# Remove this constraint once all supported ActiveSupport versions support json 3.
gem "json", "< 3"
gem "rspec-rails", "~> 7.0"
gem "byebug"

source "https://rubygems.org"

git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec path: "../"

gem "rails", '~>7.1.0'
gem "arel", github: "rails/arel"
gem "rake", ">= 11.1"
gem "rack-proxy", require: false
gem "rspec-rails", "~> 6.0.0"
gem "byebug"

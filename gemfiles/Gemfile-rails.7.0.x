source "https://rubygems.org"

git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec path: "../"

gem "rails", '~>7.0.0'
gem "rake", ">= 11.1"
gem "rack-proxy", require: false
gem "rspec-rails", "~> 7.0"
gem "byebug"
gem "concurrent-ruby", "1.3.4"

source "https://rubygems.org"

git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec path: "../"

gem "rails", '~>7.2.0'
gem "rake", ">= 11.1"
gem "rack-proxy", require: false
gem "rspec-rails", "~> 7.0"
gem "byebug"
# i18n 1.15.0 uses Fiber[] (Ruby 3.2+) but its gemspec allows Ruby >= 3.1, so Bundler
# installs it on Ruby 3.1 where Rails boot crashes. Pin until upstream fixes the gemspec.
gem "i18n", "< 1.15" if RUBY_VERSION < "3.2"

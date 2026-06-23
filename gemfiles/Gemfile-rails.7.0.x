source "https://rubygems.org"

git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec path: "../"

gem "rails", '~>7.0.0'
gem "rake", ">= 11.1"
gem "rack-proxy", require: false
gem "rspec-rails", "~> 7.0"
gem "byebug"
gem "concurrent-ruby", "1.3.4"
# i18n 1.15.0/1.15.1 call Fiber[] (Ruby 3.2+) unconditionally, crashing on Ruby 3.1.
# Fixed in 1.15.2; exclude the broken releases to keep Ruby 3.1 CI green.
gem "i18n", "!= 1.15.0", "!= 1.15.1"

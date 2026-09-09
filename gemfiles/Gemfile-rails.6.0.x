source "https://rubygems.org"

gemspec path: "../"

gem "rails", "~> 6.0.0"
gem "rake", ">= 11.1"
gem "rack-proxy", require: false
# json 3 removes the `quirks_mode` keyword passed by supported ActiveSupport versions.
# Remove this constraint once all supported ActiveSupport versions support json 3.
gem "json", "< 3"
gem "rspec-rails", "~> 5.0.0"
gem "byebug"
gem "concurrent-ruby", "1.3.4"

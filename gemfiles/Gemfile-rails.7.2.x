source "https://rubygems.org"

git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec path: "../"

gem "rails", '~>7.2.0'
gem "rake", ">= 11.1"
gem "rack-proxy", require: false
gem "rspec-rails", "~> 7.0"
gem "byebug"
if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.2")
  # i18n 1.15.x uses Fiber[] (Ruby 3.2+) while allowing Ruby 3.1.
  # Ruby 3.0/2.x are protected by i18n's gemspec; keep Ruby 3.1 below 1.15.
  gem "i18n", "< 1.15"
end

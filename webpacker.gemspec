$:.push File.expand_path("../lib", __FILE__)
require "webpacker/version"

Gem::Specification.new do |s|
  s.name     = "shakapacker"
  s.version  = Webpacker::VERSION
  s.authors  = [ "David Heinemeier Hansson", "Gaurav Tiwari", "Justin Gordon" ]
  s.email    = [ "david@basecamp.com", "gaurav@gauravtiwari.co.uk", "justin@shakacode.com" ]
  s.summary  = "Use webpack to manage app-like JavaScript modules in Rails"
  s.homepage = "https://github.com/shakacode/shakapacker"
  s.license  = "MIT"

  npm_version = Webpacker::VERSION.gsub(".rc", "-rc")
  s.metadata = {
    "source_code_uri" => "https://github.com/shakacode/shakapacker/tree/v#{npm_version}",
  }

  s.required_ruby_version = ">= 2.6.0"
  s.add_dependency("rack-proxy", ">= 0.7.2")
  s.add_dependency("nokogiri", ">= 1.13.6")
  s.add_dependency("rails-html-sanitizer", ">= 1.4.3")

  s.add_dependency "activesupport", ">= 6.0.5.1"
  s.add_dependency "railties",      ">= 6.0.5.1"
  s.add_dependency "semantic_range", ">= 3.0.0"

  s.add_development_dependency "bundler", ">= 1.3.0"
  s.add_development_dependency "rubocop"
  s.add_development_dependency "rubocop-performance"
  s.add_development_dependency("minitest")
  s.add_development_dependency("byebug")

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- test/*`.split("\n")
end

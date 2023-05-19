# This file is copied to spec/ when you run 'rails generate rspec:install'
require_relative "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
# Add additional requires below this line. Rails is not loaded until this point!

require "capybara/rails"

SERVER_BUNDLE_PATH = File.expand_path("../public/packs/server-bundle.js", __dir__)

# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?

Capybara.register_driver :selenium_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless")
  options.add_argument("--disable-gpu")
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  # config.before(:each, type: :system, js: true) do
  #   driven_by :selenium_chrome
  # end

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, type: :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/6-0/rspec-rails
  config.infer_spec_type_from_file_location!

  # Capybara config
  config.include Capybara::DSL
  #
  # selenium_firefox webdriver only works for Travis-CI builds.
  default_driver = :selenium_chrome_headless

  supported_drivers = %i[selenium_chrome_headless selenium_chrome selenium selenium_headless]
  driver = ENV["DRIVER"].try(:to_sym).presence || default_driver
  Capybara.javascript_driver = driver
  Capybara.default_driver = driver

  raise "Unsupported driver: #{driver} (supported = #{supported_drivers})" unless supported_drivers.include?(driver)

  Capybara.register_server(Capybara.javascript_driver) do |app, port|
    require "rack/handler/puma"
    Rack::Handler::Puma.run(app, Port: port)
  end

  config.before(:each, type: :system, js: true) do
    driven_by driver
  end

  config.before(:each, type: :system, rack_test: true) do
    driven_by :rack_test
  end

  # Capybara.default_max_wait_time = 15
  Capybara.save_path = Rails.root.join("tmp", "capybara")
  # Capybara::Screenshot.prune_strategy = { keep: 10 }

  # https://github.com/mattheworiordan/capybara-screenshot/issues/243#issuecomment-620423225
  # config.retry_callback = proc do |ex|
  #   Capybara.reset_sessions! if ex.metadata[:js]
  # end

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  # config.include Capybara::DSL
end

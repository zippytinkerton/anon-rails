require 'simplecov'
SimpleCov.start do
  add_filter "/vendor/"
  add_filter "/spec/support/hyperlinks.rb"
end

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  #config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"
  
  # Make "FactoryGirl" superfluous
  config.include FactoryGirl::Syntax::Methods
end


aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']
master, staging = aws_access_key_id.split(',')
aws_access_key_id = (ENV['GIT_BRANCH'] == 'staging' ? staging : master) if staging.present?
ENV['AWS_ACCESS_KEY_ID'] = aws_access_key_id

aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
master, staging = aws_secret_access_key.split(',')
aws_secret_access_key = (ENV['GIT_BRANCH'] == 'staging' ? staging : master) if staging.present?
ENV['AWS_SECRET_ACCESS_KEY'] = aws_secret_access_key

aws_region = ENV['AWS_REGION']


# ------------------------------------------------------------------------------------
# Uncomment the entire following section if you're creating a client app.
# You can delete this section if you're creating a REST service.
# ------------------------------------------------------------------------------------

# # Set up the user and password of the user used to log in to perform the tests
# TEST_API_USER = ENV['TEST_API_USER'] || TEST_API_USER

# tapw = ENV['TEST_API_PASSWORD'] || TEST_API_PASSWORD
# master, staging = tapw.split(',')
# tapw = (ENV['GIT_BRANCH'] == 'staging' ? staging : master) if staging.present?
# TEST_API_PASSWORD = tapw

# # Configure Watir
# WatirWebdriverRails.host = client_host
# WatirWebdriverRails.port = client_port
# WatirWebdriverRails.close_browser_after_finish = true

# URL = "#{client_host}:#{client_port}"

# def setup_browser(uri)
#   if RUBY_PLATFORM =~ /linux/
#     @headless = Headless.new
#     @headless.start
#     b = Watir::Browser.start uri
#   else
#     b = Watir::Browser.new ENV["browser"] || :ff
#     b.goto uri
#   end

#   # Make sure that window is maximized to not get viewport errors
#   screen_width = b.execute_script("return screen.width;")
#   screen_height = b.execute_script("return screen.height;")
#   b.driver.manage.window.resize_to(screen_width,screen_height)
#   b.driver.manage.window.move_to(0,0)
#   b
# end


# def teardown_browser(browser)
#   if RUBY_PLATFORM =~ /linux/
#     #@headless.take_screenshot "screenshot-#{rand(1000000000)}.jpg"
#     browser.close
#     @headless.destroy
#   else
#     browser.close
#   end
# end

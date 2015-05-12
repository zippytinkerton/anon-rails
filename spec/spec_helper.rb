require 'simplecov'
SimpleCov.start do
  add_filter "/config/initializers/_api_constants.rb"
  add_filter "/config/initializers/_aws_config.rb"
  add_filter "/config/initializers/_ocean_constants.rb"
  add_filter "/config/initializers/_zeromq_logger.rb"
  add_filter "/lib/ocean/zero_log.rb"
  add_filter "/lib/ocean/zeromq_logger.rb"
  add_filter "/spec/support/active_model_lint.rb"
  add_filter "/spec/support/hyperlinks.rb"
  add_filter "/vendor/"
end

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../dummy/config/environment.rb",  __FILE__)
require 'rspec/rails'
require 'webmock/rspec'
require 'factory_girl_rails'

Rails.backtrace_cleaner.remove_silencers!

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }


RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.infer_base_class_for_anonymous_controllers = false
  config.order = 'random'

  #config.include Rails.application.routes.url_helpers

  # Make "FactoryGirl" superfluous
  config.include FactoryGirl::Syntax::Methods

  # To clear the fake_dynamo DB before each run, uncomment the following line:
  # config.before(:suite) { system "curl -X DELETE http://localhost:4567" }

  config.infer_spec_type_from_file_location!
end

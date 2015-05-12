# Update the Gemfile
gem "ocean-rails"

# Install a .rvmrc file
run "rvm rvmrc create ruby-2.2.2@rails-4.2.1"
# Select the ruby and gem bag
run "rvm use ruby-2.2.2@rails-4.2.1"
# Run bundle install - we need the generators in it now
run "bundle install"

# Create a temporary config.yml file
file 'config/config.yml', <<-CODE
# This is a temporary file which will be overwritten during setup
BASE_DOMAIN: example.com
CODE

# Set up the application as a SOA service Rails application
generate "ocean_setup", app_name

# Install the required gems and package them with the app
run "bundle install"
run "bundle package --all"

# Remove the asset stuff from the application conf file
gsub_file "config/application.rb", 
          /    # Enable the asset pipeline.+config\.assets\.version = '1\.0'\s/m, ''

# Set up SQLite to run tests in memory
gsub_file "config/database.yml",
          /test:\s+adapter: sqlite3\s+database: db\/test.sqlite3/m,
          'test:
  adapter: sqlite3
  database: ":memory:"
  verbosity: quiet'

# Get the DBs in order
rake "db:migrate"

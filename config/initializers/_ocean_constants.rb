#
# This file will be replaced by an auto-generated one in deployment.
# YOU SHOULD NEVER CHANGE THE CONTENTS OF THIS FILE.
#
# Backend developers should never need to override the value here.
# The reason for this is that when  developing services locally, 
# their tests run in isolation with all external calls mocked away, 
# and thus it doesn't matter what URLs a service generates when 
# running tests locally on a developer's machine.
#
# If you're a frontend developer, however, the point of your testing
# is to exercise the entire SOA and thus you need access to a
# complete and fully functional system (which might or might not
# make calls to partners' systems, such as for hotel bookings).
# 
# Thus, if you are a frontend developer, you override the string
# constant here to reflect the Chef environment (master, staging)
# you wish to run your local tests against by defining the environment
# variable OCEAN_API_HOST.
#
# When TeamCity runs its tests, it will set these constants to values
# appropriate for the Chef environment for which the tests are run.
# Thus, TeamCity will always run master branch frontend tests against
# the master Chef environment. However, you can run a personal build
# and specify the OCEAN_API_HOST value as an environment param in the
# build dialog.
#

BASE_DOMAIN = "example.com" unless defined?(BASE_DOMAIN)  # For the Rails template generator

OCEAN_API_HOST = (ENV['OCEAN_API_HOST'] || 
                  (Rails.env == 'test' && "forbidden.#{BASE_DOMAIN}") || 
                  "master-api.#{BASE_DOMAIN}"
                 ).sub("<default>", "master")
                
OCEAN_API_URL = "https://#{OCEAN_API_HOST}"

INTERNAL_OCEAN_API_URL = OCEAN_API_URL.sub("https", "http").sub("api.", "lb.")

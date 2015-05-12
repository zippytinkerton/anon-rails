$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "ocean/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "ocean-rails"
  s.version     = Ocean::VERSION
  s.authors     = ["Peter Bengtson"]
  s.email       = ["peter@peterbengtson.com"]
  s.homepage    = "https://github.com/OceanDev/ocean-rails"
  s.summary     = "This gem implements common Ocean behaviour for Ruby and Ruby on Rails."
  s.description = 
"== Ocean

Ocean is an architecture for creating server-oriented architectures (SOAs) in the cloud. 
It consists of two separate parts which can be used separately or in conjunction: Ocean and OceanFront.

Ocean is a complete and very scalable back end solution for RESTful JSON web services and web applications, 
featuring aggressive caching and full HTTP client abstraction. Ocean fully implements HATEOAS principles, 
allowing the programming object model to move fully out onto the net, while maintaining a very high degree 
of decoupling.

Ocean is also a development, staging and deployment pipeline featuring continuous integration and testing in a 
TDD and/or BDD environment. Ocean can be used for continuous deployment or for scheduled releases. Front end tests 
are run in parallel using a matrix of operating systems and browser types. The pipeline can very easily be extended 
with new development branches and quality assurance environments with automatic testing and deployment.

OceanFront is a cross-platform Javascript front end browser client library supporting all major browsers and 
platforms. OceanFront is object oriented, widget-based and HTML-less.

Together, Ocean and OceanFront allow you to write front end code completely independent of browser type and client 
OS, and back end code completely agnostic of whether it is called by a client browser or another server system."

  s.required_ruby_version = '>= 2.0.0'
  s.license = 'MIT'

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]

  s.add_dependency "typhoeus"           # We use Typhoeus for all HTTP requests
  s.add_dependency "ffi"                # FFI
  s.add_dependency "ffi-rzmq", "~> 1.0" # ZeroMQ (this version requirement should be lifted)
  s.add_dependency "rack-attack"        # Flooding, etc.
  s.add_dependency "jbuilder"           # We use Jbuilder to render our JSON responses
  
  s.add_dependency "ocean-dynamo"

  s.add_development_dependency "rails", "~> 4"
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "webmock"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "factory_girl_rails", "~> 4.0"
end

require "ocean/engine"

require "ocean-dynamo"
require "ocean/api"
require "ocean/api_resource"
require "ocean/ocean_resource_model" if defined? ActiveRecord || defined? OceanDynamo
require "ocean/ocean_resource_controller" if defined? ActionController
require "ocean/ocean_application_controller"
require "ocean/zero_log"
require "ocean/zeromq_logger"
require "ocean/selective_rack_logger"
require "ocean/flooding"
require "ocean/api_remote_resource"


INVALIDATE_MEMBER_DEFAULT =     ["($|/|\\?)"]
INVALIDATE_COLLECTION_DEFAULT = ["($|\\?)"]


module Ocean

  class Railtie < Rails::Railtie
    # Silence the /alive action
    initializer "ocean.swap_logging_middleware" do |app|
      app.middleware.swap Rails::Rack::Logger, SelectiveRackLogger
    end
    # Make sure the generators use the gem's templates first
    config.app_generators do |g|
      g.templates.unshift File::expand_path('../templates', __FILE__)
    end 
  end
  
end


#
# For stubbing successful authorisation calls. Makes <tt>Api.permitted?</tt> return
# the status, and a body containing a partial authentication containing the +user_id+ 
# and +creator_uri+ given by the parameters. It also allows the value of 'right' to
# be specified: this will restrict all SQL queries accordingly.
#
def permit_with(status, user_id: 123, creator_uri: "https://api.example.com/v1/api_users/#{user_id}",
                        right: nil, group_names: [])
  allow(Api).to receive(:permitted?).
    and_return(double(:status => status, 
                      :body => {'authentication' => 
                                 {'user_id' => user_id,
                                  'right' => right,
                                  'group_names' => group_names,
                                  '_links' => { 'creator' => {'href' => creator_uri,
                                                              'type' => 'application/json'}}}}))
end


#
# For stubbing failed authorisation calls. Makes <tt>Api.permitted?</tt> return the
# given status and a body containing a standard API error with the given error messages.
#
def deny_with(status, *error_messages)
  allow(Api).to receive(:permitted?).
    and_return(double(:status => status, 
                      :body => {'_api_error' => error_messages}))
end


#
# Takes a relation and adds right restrictions, if present.
#
def add_right_restrictions(rel, restrictions)
  return rel unless restrictions
  # First get the table to use as a basis for the OR clauses
  t = rel.arel_table
  # Accumulating Arel AND clauses
  cond = restrictions.reduce [] do |acc, rr|
    app = rr['app']
    context = rr['context']
    if    app != '*' && context != '*'
      acc << t[:app].eq(app).and(t[:context].eq(context))
    elsif app != '*' && context == '*'
      acc << t[:app].eq(app)
    elsif app == '*' && context != '*'
      acc << t[:context].eq(context)
    end
    acc
  end
  # Process the clauses. We might not need to OR anything.
  case cond.length
  when 0
    return rel
  when 1
    return rel.where(cond.first)
  else
    # OR the multiple clauses together
    cond = cond.reduce :or
    # Return a relation built from the Arel condition we've constructed
    rel.where(cond)
  end
end

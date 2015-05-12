#
# This custom Rack middleware is used to turn off logging of requests made to
# <code>/alive</code> by Varnish every 15 seconds in order to detect 
# failing instances for failover purposes.
#
class SelectiveRackLogger < Rails::Rack::Logger

  #
  # Initialises the selective Rack logger.
  #
  def initialize(app, opts = {})
    @app = app
    super
  end

  #
  # Suppresses logging of /alive requests from Varnish.
  #
  def call(env)
    if env['PATH_INFO'] == "/alive"
      old_level = Rails.logger.level
      Rails.logger.level = 1234567890              # > 5
      begin
        @app.call(env)                             # returns [..., ..., ...]
      ensure
        Rails.logger.level = old_level
      end
    else
      super(env)                                   # returns [..., ..., ...]
    end
  end
end


class Rails::Rack::Logger

  protected

  #
  # Monkey patch: no started_request_message logged in production.
  #
  def call_app(request, env)
    # Put some space between requests in development logs.
    if development?
      logger.debug ''
      logger.debug ''
    end

    instrumenter = ActiveSupport::Notifications.instrumenter
    instrumenter.start 'request.action_dispatch', request: request
    logger.info started_request_message(request) unless Rails.env.production?
    resp = @app.call(env)
    resp[2] = ::Rack::BodyProxy.new(resp[2]) { finish(request) }
    resp
  rescue
    finish(request)
    raise
  ensure
    ActiveSupport::LogSubscriber.flush_all!
  end
end

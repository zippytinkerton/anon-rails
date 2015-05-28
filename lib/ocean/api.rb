require 'typhoeus'

#
# This class encapsulates all logic for calling other API services.
#
class Api

  #
  # Convert an external Ocean URI to an internal one. This is mainly useful
  # in master and staging, as the https URIs aren't available for CronJobs,
  # etc.
  #
  def self.internalize_uri(uri, chef_env=CHEF_ENV)
    uri.sub(OCEAN_API_URL, INTERNAL_OCEAN_API_URL)
  end

  
  #
  # When given a symbol or string naming a resource, returns a string 
  # such as +v1+ naming the latest version for the resource.
  #
  def self.version_for(resource_name)
    API_VERSIONS[resource_name.to_s] || API_VERSIONS['_default']
  end
  

  #
  # Adds environment info to the basename, so that testing and execution in various combinations
  # of the Rails env and the Chef environment can be done without collision. 
  #
  # The chef_env will always be appended to the basename, since we never want to share queues 
  # between different Chef environments. 
  #
  # If the chef_env is 'dev' or 'ci', we must separate things as much as
  # possible: therefore, we add the local IP number and the Rails environment. 
  #
  # We also add the same information if by any chance the Rails environment isn't 'production'. 
  # This is a precaution; in staging and prod apps should always run in Rails production mode, 
  # but if by mistake they don't, we must prevent the production queues from being touched.
  #
  # If +suffix_only+ is true, the basename will be excluded from the returned string.
  #
  def self.adorn_basename(basename, chef_env: "dev", rails_env: "development",
                          suffix_only: false)
    fullname = suffix_only ? "_#{chef_env}" : "#{basename}_#{chef_env}"
    if rails_env != 'production' || chef_env == 'dev' || chef_env == 'ci'
      local_ip = UDPSocket.open {|s| s.connect("64.233.187.99", 1); s.addr.last}.gsub('.', '-')
      fullname += "_#{local_ip}_#{rails_env}"
    end
    fullname
  end


  #
  # Like +adorn_basename+, but returns only the suffix. Uses CHEF_ENV and Rails.env.
  #
  def self.basename_suffix
    adorn_basename '', suffix_only: true, chef_env: CHEF_ENV, rails_env: Rails.env
  end


  #
  # Api::Response instances wrap Typhoeus responses as an abstraction layer, but also
  # in order to provide lazy evaluation of headers and JSON decoding of the body.
  #
  class Response
    
    def initialize(response)
      @response = response
      @headers = nil
      @body = nil
    end

    #
    # The request which yielded this response.
    #
    def request
      @response.request
    end

    #
    # The status code of the HTTP response.
    #
    def status
      @response.response_code
    end

    #
    # The status message of the HTTP response.
    #
    def message
      @response.status_message
    end

    #
    # Returns a hash of HTTP response headers.
    #
    def headers
      @headers ||= (@response.response_headers || "").split("\r\n").inject({}) do |acc, h|
                     k, v = h.split(": ")
                     acc[k] = v
                     acc
                   end
    end

    #
    # Returns the HTTP response body parsed from JSON. This is done lazily and only once.
    #
    def body

      @body ||= @response.response_body.blank? ? nil :  begin
                                                          JSON.parse(@response.response_body)
      rescue => error
      Rails.logger.info ">>> OCEAN RESPONSE JSON PARSE EXCEPTION. Body: #{@response.response_body}"
      end
    end

    #
    # Returns the original HTTP response body as a String.
    #
    def raw_body
      @response.response_body
    end

    #
    # Returns true if the HTTP request was a success and status == 2xx.
    #
    def success?
      @response.success?
    end

    #
    # Returns true if the HTTP request timed out.
    #
    def timed_out?
      @response.timed_out?
    end

    #
    # Returns true if the HTTP response was a success and not a 304.
    #
    def modified?
      @response.modified?
    end
  end


  #
  # Api.request is designed to be the lowest common denominator for making any kind of
  # HTTP request, except parallel requests which will have a similar method (to which BAN
  # and PURGE requests to Varnish is a special case).
  #
  # In its present form it assumes the request is a JSON one. Eventually, keyword args will
  # provide abstract control of content type.
  #
  # +url+ is the URL to which the request will be made.
  # +http_method+ is the HTTP method to use (:post, :get, :head, :put, :delete, etc).
  # +args+, if given, should be a hash of query arguments to add to the URL.
  # +headers+, if given, is a hash of extra HTTP headers for the request.
  # +body+, if given, is the body of the request (:post, :put) as a string.
  # +credentials, if given, are the credentials to use when authenticating.
  # +x_api_token+, if given, is a string which will be used as an X-API-Token header.
  # +reauthentication+ (true by default), controls whether 400 and 419 will trigger reauth.
  # +ssl_verifypeer+ (true by default), controls SSL peer verification.
  # +ssl_verifyhost+ (2 by default), controls SSL host verification.
  #
  # Automatic retries for GET requests are available:
  #
  # +retries+, if given and > 0, specifies the number of retries to perform for GET requests.
  #            Defaults to 0, meaning no retries.
  # +backoff_time+ (default 1) the initial time to wait between retries. 
  # +backoff_rate+ (default 0.9) the rate at which the time is increased.
  # +backoff_max+ (default 30) the maximum time to wait between retries.
  #
  # The backoff time is increased after each wait period by the product of itself and 
  # backoff_rate. The backoff time is capped by backoff_max. The default time and rate
  # settings will generate the progression 1, 1.9, 3.61, 6.859, 13.0321, 24.76099, 30, 30, 
  # 30, etc. To disable waiting between retries entirely, set +backoff_time+ to zero.
  #
  def self.request(url, http_method, args: nil, headers: {}, body: nil,
                   credentials: nil,
                   x_api_token: headers['X-API-Token'], 
                   reauthentication: true,
                   ssl_verifypeer: true, ssl_verifyhost: 2,
                   retries: 0, backoff_time: 1, backoff_rate: 0.9, backoff_max: 30,
                   x_metadata: Thread.current[:metadata],
                   &block)
    # Set up the request
    headers['Accept'] = "application/json"
    headers['Content-Type'] = "application/json" if [:post, :put].include?(http_method)
    headers['User-Agent'] = "Ocean"
    x_api_token =  Api.authenticate(*Api.decode_credentials(credentials)) if x_api_token.blank? && credentials.present?
    headers['X-API-Token'] = x_api_token if x_api_token.present?
    headers['X-Metadata'] = x_metadata if x_metadata.present?

    retries = 0 unless ["GET", "HEAD"].include? http_method.to_s.upcase

    @hydra ||= Typhoeus::Hydra.hydra

    request = nil   
    response = nil
    response_getter = lambda { response }

    url = url.first == "/" ? "#{INTERNAL_OCEAN_API_URL}#{url}" : Api.internalize_uri(url)

    start_time = Time.now
    got_response = false
    req_id = Random.rand(999999)
    begin
      if !got_response
        got_response = true
        reqlog = {
          'url' => url,
          'method' => http_method,
          'headers' => headers,
          'metadata'=> x_metadata,
          'reauthentication'=> reauthentication,
          'body' => body,
          'req-id' => req_id
        }
        Rails.logger.info ">>> OCEAN REQUEST #{reqlog}"
      end
    rescue => error
      Rails.logger.info ">>> OCEAN REQUEST exception #{error}"
    end

    # This is a Proc when run queues the request and schedules retries
    enqueue_request = lambda do
      # First construct a request. It will not be sent yet.
      request = Typhoeus::Request.new(url,
                                      method: http_method, 
                                      headers: headers,
                                      params: args, 
                                      body: body, 
                                      ssl_verifypeer: ssl_verifypeer,
                                      ssl_verifyhost: ssl_verifyhost)
      # Define a callback to process the response and do retries
      request.on_complete do |typhoeus_response|
        response = Response.new typhoeus_response
    begin
      resp = response || {}
      reslog = {
        'calling_url' => url,
        'status' => resp.status,
        'headers' => resp.headers,
        'metadata'=> x_metadata,
        'time' => "#{Time.now - start_time} s",
        'body' => resp.body,
        'req-id' => req_id
      }
      Rails.logger.info "<<< OCEAN PARALLEL RESPONSE #{reslog}"
    rescue => error
      Rails.logger.info "<<< OCEAN PARALLEL RESPONSE exception #{error}"
    end

        case response.status
        when 100..199
          enqueue_request.call  # Ignore and retry
        when 200..299, 304
          # Success, call the post-processor if any. Any further Api.request
          # calls done by the post-processor will use the same response
          # accessors, which means the final result will be what the last
          # post-processor to finish returns.
          response = block.call(response) if block
        when 300..399
          nil  # Done, redirect
        when 400, 419
          if reauthentication && x_api_token.present?
            # Re-authenticate and retry
            if credentials
              x_api_token = Api.authenticate(*Api.decode_credentials(credentials))
              headers['X-API-Token'] = x_api_token
            else
              Api.reset_service_token
              headers['X-API-Token'] = Api.service_token
            end
            reauthentication = false   # This prevents us from ending up here twice
            enqueue_request.call
          else
            nil  # Done, fail
          end          
        when 400..499
          nil  # Done, fail
        else
          # We got a 5xx. Retry if there are any retries left
          if retries > 0
            retries -= 1
            sleep backoff_time
            backoff_time = [backoff_time + backoff_time * backoff_rate, backoff_max].min
            enqueue_request.call
          else
            nil  # Done, don't retry
          end
        end
      end

      # Finally, queue the request (and its callback) for execution
      @hydra.queue request
      # Return nil, to emphasise that the side effects are what's important
      nil
    end

    # So create and enqueue the request
    enqueue_request.call
    # If doing parallel calls, return a lambda which returns the final response
    return response_getter if Api.simultaneously?
    # Run it now. Blocks until completed, possibly after any number of retries
    @hydra.run
    if response.is_a?(Response)
      # Raise any exceptions
      if response.timed_out?
        Rails.logger.info "<<< OCEAN TIMED OUT RESPONSE response: #{response} req-id: #{req_id}"
      end
      if response.status == 0
        Rails.logger.info "<<< OCEAN RESPONSE STATUS 0 RESPONSE response: #{response} req-id: #{req_id}"
      end
      raise Api::TimeoutError, "Api.request timed out" if response.timed_out?
      raise Api::NoResponseError, "Api.request could not obtain a response" if response.status == 0
    end

    begin
      if !got_response
        got_response = true
        resp = response || {}
        reslog = {
          'calling_url' => url,
          'status' => resp.status,
          'headers' => resp.headers,
          'metadata'=> x_metadata,
          'time' => "#{Time.now - start_time} s",
          'body' => resp.body,
          'req-id' => req_id
        }
        Rails.logger.info "<<< OCEAN NORMAL RESPONSE #{reslog}"
      end
    rescue => error
      Rails.logger.info "<<< OCEAN NORMAL RESPONSE exception #{error}"
    end
    response
  end


  # 
  # Api.simultaneously is used for making requests in parallel. For example:
  #
  #  results = Api.simultaneously do |r|
  #    r << Api.request("http://foo.bar", :get, retries: 3)
  #    r << Api.request("http://foo.baz", :get, retries: 3)
  #    r << Api.request("http://foo.quux", :get, retries: 3)
  #  end
  #
  # The value returned is an array of responses from the Api.request calls. If a request
  # has a post-processor block, the result will not be the response but what the block
  # returns.
  #
  # TimeoutErrors and NoResponseError will not be raised in parallel mode.
  #
  # Only Api.request is supported at the present time. Api::RemoteResource will follow.
  #
  def self.simultaneously (&block)
    raise "block required" unless block
    @inside_simultaneously = true   
    results = []
    @hydra = nil 
    block.call(results)
    Typhoeus::Config.memoize = true   
    @hydra.run if @hydra
    results.map(&:call)
  ensure
    @inside_simultaneously = false
  end


  def self.simultaneously?
    @inside_simultaneously ||= false
  end


  class TimeoutError < StandardError; end
  class NoResponseError < StandardError; end


  #
  # Makes an internal +PURGE+ call to all Varnish instances. The call is made in parallel.
  # Varnish will only accept +PURGE+ requests coming from the local network.
  #
  def self.purge(*args)  
    hydra = Typhoeus::Hydra.hydra
    LOAD_BALANCERS.each do |host| 
      url = "http://#{host}#{path}"
      request = Typhoeus::Request.new(url, method: :purge, headers: {})
      hydra.queue request
    end
    hydra.run
  end


  #
  # Makes an internal +BAN+ call to all Varnish instances. The call is made in parallel.
  # Varnish will only accept +BAN+ requests coming from the local network.
  #
  def self.ban(path)     
    hydra = Typhoeus::Hydra.hydra
    escaped_path = escape(path)
    LOAD_BALANCERS.each do |host| 
      url = "http://#{host}#{escaped_path}"
      request = Typhoeus::Request.new(url, method: :ban, headers: {})
      hydra.queue request
    end
    hydra.run
  end


  #
  # This escapes BAN request paths, which is needed as they are regexes.
  #
  def self.escape(path)
    URI.escape(path, Regexp.new("[^/$\\-+_.!~*'()a-zA-Z0-9]"))
  end


  #
  # This method returns the current token. If no current token has been obtained,
  # authenticates.
  #
  def self.service_token
    @service_token ||= authenticate
  end

  #
  # Resets the service token, causing the next call to Api.service_token to
  # re-authenticate.
  #
  def self.reset_service_token
    @service_token = nil
  end

  
  #
  # Authenticates against the Auth service (which must be deployed and running) with
  # a given +username+ and +password+. If successful, the authentication token is returned.
  # If the credentials match the service's own, the token is also assigned to the instance variable @service_token. 
  # If not successful, +nil+ is returned.
  #
  def self.authenticate(username=API_USER, password=API_PASSWORD)
    # response = request "/v1/authentications", :post,
    #                    headers: {'X-API-Authenticate' => credentials(username, password)}
    url = "#{INTERNAL_OCEAN_API_URL}/v1/authentications"

    start_time = Time.now
    begin
      reqlog = {
        'url' => url
      }
      Rails.logger.info ">>> OCEAN AUTH REQUEST #{reqlog}"
    rescue => error
      Rails.logger.info ">>> OCEAN AUTH REQUEST exception #{error}"
    end#

    response = Typhoeus.post url, body: "", headers: {'X-API-Authenticate' => credentials(username, password)}

    begin
      resp = response || {}
      reslog = {
        'calling_url' => url,
        'status' => resp.code,
        'time' => "#{Time.now - start_time} s",
        'body' => resp.body
      }
      Rails.logger.info "<<< OCEAN AUTH RESPONSE #{reslog}"
    rescue => error
      Rails.logger.info "<<< OCEAN AUTH RESPONSE exception #{error}"
    end

    case response.code
    when 201
      token = JSON.parse(response.body)['authentication']['token']
      @service_token = token if username == API_USER && password == API_PASSWORD
      token
    when 400
      # Malformed credentials. Don't repeat the request.
      nil
    when 403
      # Does not authenticate. Don't repeat the request.
      nil 
    when 500
      # Error. Don't repeat. 
      nil   
    else
      # Should never end up here.
      raise "Authentication failiure. Status: #{response.code} body:#{response.body}"
    end
  end
  

  #
  # Encodes a username and password for authentication in the format used for standard HTTP 
  # authentication. The encoding can be reversed and is intended only to lightly mask the
  # credentials so that they're not immediately apparent when reading logs.
  #
  def self.credentials(username=nil, password=nil)
    raise "Only specifying the username is not allowed" if username && !password
    username ||= API_USER
    password ||= API_PASSWORD
    ::Base64.strict_encode64 "#{username}:#{password}"
  end
  

  #
  # Takes encoded credentials (e.g. by Api.encode_credentials) and returns a two-element array
  # where the first element is the username and the second is the password. If the encoded
  # credentials are missing or can't be decoded properly, ["", ""] is returned. This allows
  # you to write:
  #   
  #   un, pw = Api.decode_credentials(creds)
  #   raise "Please supply your username and password" if un.blank? || pw.blank?
  #
  def self.decode_credentials(encoded)
    return ["", ""] unless encoded
    username, password = ::Base64.decode64(encoded).split(':', 2)
    [username || "", password || ""]
  end
  

  #
  # Performs authorisation against the Auth service. The +token+ must be a token received as a 
  # result of a prior authentication operation. The args should be in the form
  #
  #   query: "service:controller:hyperlink:verb:app:context"
  #
  # e.g.
  #
  #   Api.permitted?(@service_token, query: "cms:texts:self:GET:*:*")
  #
  # Api.authorization_string can be used to produce the query string.
  # 
  # Returns the HTTP response as-is, allowing the caller to examine the status code and
  # messages, and also the body.
  #
  def self.permitted?(token, args={})
    raise unless token
    Api.request "/v1/authentications/#{token}", :get, args: args
  end  


  #
  # Returns an authorisation string suitable for use in calls to Api.permitted?. 
  # The +extra_actions+ arg holds the extra actions as defined in the Ocean controller; it must
  # be included here so that actions can be mapped to the proper hyperlink and verb.
  # The +controller+ and +action+ args are mandatory. The +app+ and +context+ args are optional and will
  # default to "*". The last arg, +service+, defaults to the name of the service itself.
  #
  def self.authorization_string(extra_actions, controller, action, app="*", context="*", service=APP_NAME)
    app = '*' if app.blank?
    context = '*' if context.blank?
    hyperlink, verb = Api.map_authorization(extra_actions, controller, action)
    "#{service}:#{controller}:#{hyperlink}:#{verb}:#{app}:#{context}"
  end


  #
  # These are the default controller actions. The purpose of this constant is to map action
  # names to hyperlink and HTTP method (for authorisation purposes). Don't be alarmed by the
  # non-standard GET* - it's purely symbolic and is never used as an actual HTTP method. 
  # We need it to differentiate between a +GET+ of a member and a +GET+ of a collection of members. 
  # The +extra_actions+ keyword in +ocean_resource_controller+ follows the same format.
  #
  DEFAULT_ACTIONS = {
    'show' =>    ['self', 'GET'],
    'index' =>   ['self', 'GET*'],
    'create' =>  ['self', 'POST'],
    'update' =>  ['self', 'PUT'],
    'destroy' => ['self', 'DELETE'],
    'connect' =>    ['connect', 'PUT'],
    'disconnect' => ['connect', 'DELETE']
  }


  #
  # Returns the hyperlink and HTTP method to use for an +action+ in a certain +controller+.
  # First, the +DEFAULT_ACTIONS+ are searched, then any extra actions defined for the
  # controller. Raises an exception if the action can't be found.
  #
  def self.map_authorization(extra_actions, controller, action)
    DEFAULT_ACTIONS[action] ||
    extra_actions[controller][action] ||
    raise #"The #{controller} lacks an extra_action declaration for #{action}"
  end


  #
  # Send an email asynchronously. The Mailer role is required.
  #
  def self.send_mail(from: "nobody@#{BASE_DOMAIN}", to: nil, 
                     subject: nil, 
                     plaintext: nil, html: nil,
                     plaintext_url: nil, html_url: nil, substitutions: nil)
    Api.request "/v1/mails", :post, 
      x_api_token: Api.service_token, credentials: Api.credentials,
      body: {
        from: from, to: to, subject: subject, 
        plaintext: plaintext, html: html,
        plaintext_url: plaintext_url, html_url: html_url, 
        substitutions: substitutions
      }.to_json
  end


  #
  # Constructs a hash suitable as the body of a POST to async_jobs. It lets you set
  # all the allowed attributes, and it also provides a terse shortcut for one-step
  # jobs (by far the most common ones). The following:
  #
  #   Api.async_body "/v1/foos", :put
  #
  # is equivalent to
  #
  #   Api.async_body steps: [{"url" => "#{INTERNAL_OCEAN_API_URL}/v1/foos"}
  #                           "method" => "PUT",
  #                           "body" => {}}]
  # 
  # A URL not starting with a / will be internalized.
  #
  def self.async_job_body(href=nil, method=:get, body: {},
                          credentials: nil, 
                          token: nil,
                          steps: nil,
                          default_step_time: nil, 
                          default_poison_limit: nil,
                          max_seconds_in_queue: nil,
                          poison_email: nil)
    h = {}
    unless steps
      method = method && method.to_s.upcase
      href = href && (href.first == "/" ? "#{INTERNAL_OCEAN_API_URL}#{href}" : Api.internalize_uri(href))
      steps = if href && method
                if ["POST","PUT"].include? method 
                  [{"url" => href, "method" => method, "body" => body}]
                else
                  [{"url" => href, "method" => method}]
                end
              end
      steps ||= []
    end
    h['steps'] = steps
    h['credentials'] = credentials || Api.credentials
    h['token'] = token || Api.service_token
    h['default_step_time'] = default_step_time if default_step_time
    h['default_poison_limit'] = default_poison_limit if default_poison_limit
    h['max_seconds_in_queue'] = max_seconds_in_queue if max_seconds_in_queue
    h['poison_email'] = poison_email if poison_email
    h
  end


  #
  # Takes the same args as +.async_job_body+, post an +AsyncJob+ and returns the +Response+.
  # The +AsyncJob+ is always created as the service +ApiUser+; the job carries its own
  # credentials and token, specified as keywords +:credentials+ and +:token+.
  # If you have precomputed the job description hash, pass it using the keyword
  # +:job+ as the only parameter.
  #
  # A block may be given. It will be called with any +TimeoutError+ or +NoResponseError+,
  # which allows +Api.run_async_job+ to be used very tersely in controllers, e.g.:
  #
  #   Api.run_async_job(...) do |e| 
  #     render_api_error 422, e.message
  #     return
  #   end
  # 
  def self.run_async_job(href=nil, method=nil, job: nil, **keywords, &block)
    job ||= async_job_body(href, method, **keywords)
    Api.request "/v1/async_jobs", :post,
      body: job.to_json, x_api_token: Api.service_token
  rescue TimeoutError, NoResponseError => e
    raise e unless block
    block.call e
  end

end

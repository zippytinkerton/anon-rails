class Api

  #
  # This class represents an Ocean resource accessed by a URI. 
  # 
  # The resource is read lazily. Retries and back off properties are available.
  #
  #   thing = Api::RemoteResource.new("http://api.example.com/things/1")
  #   thing.present? => false
  #   thing['some_attr'] => {"this" => "is", "just" => "an example"}
  #   thing.present? => true
  #   
  #   thing.resource_type => 'thing'
  #   thing.status => 200
  #   thing.status_message => "OK"
  #   thing.response => #<an Api::Response instance>
  #   thing.etag => "e4552f0ae517f0352f0ae56222fa0733ea52f0ae5e0"
  #
  # The last raw body can be read:
  #
  #   thing.raw => nil or {"foo" => {...}}
  #
  # Headers can be read or set:
  #
  #   thing.headers => {...}
  #   thing.headers['X-Some-Header'] = "Zalagadoola"
  #
  # Attributes can be read or set:
  #
  #   thing['foo'] = "bar"
  #   thing['foo'] = "newbar"
  #
  # Hyperlinks can be read:
  #
  #   thing.hyperlink['self'] => {"href"=>"http://api.example.com/things/1", 
  #                               "type"=>"application/json"}
  #
  # These are defined for convenience:
  #
  #   thing.href => "http://api.example.com/things/1"
  #   thing.type => "application/json"
  #
  # The following two are equivalent:
  #
  #   Api::RemoteResource.get("foo")         always returns a new RemoteResource
  #   Api::RemoteResource.new("foo").get     always returns the RemoteResource  
  #
  # as are:
  #
  #   Api::RemoteResource.get!("foo")        returns a new RemoteResource or raises an error
  #   Api::RemoteResource.new("foo").get!    returns the RemoteResource or raises an error
  #
  # +thing.get!+ returns the RemoteResource if successful. If not, raises an exception.
  # +thing.get+ does the same, but always returns the RemoteResource. The remote resource
  # can be examined to see its status.
  #
  # Hyperlinks can be specified to avoid hardcoding API URIs. Simply specify
  # the hyperlink as the first parameter to the instance versions of the HTTP accessors:
  #
  #   x = Api::RemoteResource.new("http://foo.com/x")
  #   x.get(:creator)
  #   x.get!(:creator)['username']
  #   x.put(:confirm, body: {x:2, y:3})
  #   x.post(:login, body: {username: "Bl0feld", password: "SPECTRE"})
  #   x.delete(:expired)
  #
  # Note the difference between:
  #
  #   x.put(body: {x:2, y:3})
  #   x.put(:self, body: {x:2, y:3})
  #   x.put(:confirm, body: {x:2, y:3})
  #
  # The first two are logically equivalent: they both make a PUT request to x itself,
  # though in the second case, the self hyperlink is explicit (the first arg defaults to
  # :self). The third case sends a PUT request to x's hyperlink :confirm. From this follows
  # that the following also are equivalent:
  #
  #   x.get
  #   x.get(:self)
  #
  # #post, #post!, #put, #put!, #delete, and #delete! are also available and have the same
  # hyperlink handling capabilities.
  #
  # Exceptions:
  #
  #   GetFailed             raised when the GET to obtain the resource has failed.
  #   ConditionalGetFailed  raised when a Conditional Get to refresh the resource has failed.
  #   PutFailed             raised when a PUT on the resource has failed.
  #   PostFailed            raised when a POST to the resource has failed.
  #   DeleteFailed          raised when a DELETE of the resource has failed.
  #   UnparseableJson       raised when the response body doesn't parse as JSON.
  #   JsonIsNoResource      raised when the structure of the parsed JSON body is not a resource.
  #   HyperlinkMissing      raised when a hyperlink isn't available.
  #
  # To parse as a resource, the JSON must be a wrapped Ocean resource of this format:
  #
  #  {"thing": {
  #     "_links": {
  #       "self": {"href": "https://....", type: "application/json"},
  #       ...
  #     },
  #     "foo": 2,
  #     "bar": [1,2,3],
  #     ...
  #  }
  #
  # The above is a Thing resource, wrapped with its type. Attributes should appear in the inner
  # hash, which must have at least a +_links+ hyperlink attribute with a href and a content type. 
  #
  # If any of the four getters (.get!, .get, #get!, and #get) receive an Ocean collection, 
  # the instance method +#collection+ will return an array of RemoteResources. NB: the getters
  # will still, in all cases, return the RemoteResource itself. The collection is always made
  # available as the value of +#collection+ on the RemoteResource which was used to obtain it.
  #
  # To refresh a resource using a conditional GET:
  #
  #   thing.refresh
  #   thing.refresh!
  #
  # Both return the resource itself, so you can do
  #
  #   thing.refresh['updated_at']
  #
  #
  # NB: this class can also be used to fetch any JSON data. E.g.:
  #
  #   Api::RemoteResource.get("http://example.com/anything").raw
  #
  # +#raw+ will return any raw data received, even if it wasn't recognised as an Ocean resource
  # and +JsonIsNoResource+ was raised. The +.get+ will suppress any exceptions. If +#raw+ returns 
  # +nil+, you can always chack +#status+, +#status_message+, and/or +#headers+ to determine what
  # went wrong. After fetching non-resource data, +#present?+ will always be false.
  #
  class RemoteResource

  	attr_reader :uri, :args, :content_type, :retries, :backoff_time, :backoff_rate, :backoff_max
    attr_reader :raw, :resource, :resource_type, :status, :headers, :credentials, :x_api_token
    attr_reader :status_message, :response, :etag, :collection

    #
    # The credentials and the x_api_token, if both are left unspecified, will default to
    # the local credentials and service token. If both are specified and different from
    # the default values, they will be used instead. Specifying only one of them is not
    # permitted.
    #
  	def initialize(uri, type="application/json", args: nil,
                   credentials: nil, x_api_token: nil,
  		             retries: 3, backoff_time: 1, backoff_rate: 0.9, backoff_max: 30)
      super()
  	  @uri = uri
      @args = args
  	  @content_type = type
      @retries = retries
      @backoff_time = backoff_time
      @backoff_rate = backoff_rate
      @backoff_max = backoff_max
      @present = false
      @raw = nil
      @resource = nil
      @resource_type = nil
      @status = nil
      @status_message = nil
      @headers = nil
      @credentials = credentials
      @x_api_token = x_api_token
      @collection = false
  	end

    #
    # True if the resource has been read successfully.
    #
    def present?
      @present
    end

    #
    # Returns a resource attribute. If the resource isn't present, +get!+ will be used to
    # retrieve it.
    #
    def [](key)
      get! unless present?
      resource[key]
    end

    #
    # Sets a resource attribute. The resource will not be retrieved if not present.
    #
    def []=(key, value)
      resource[key] = value
    end

    #
    # Returns the hash of hyperlinks. The resource will not be retrieved if not present.
    #
    def hyperlink
      self['_links']
    end

    #
    # Returns resources own href. The resource will not be retrieved if not present.
    #
    def href
      hyperlink['self']['href']
    end

    #
    # Returns resources own content type. The resource will not be retrieved if not present.
    #
    def type
      hyperlink['self']['type']
    end

    #
    # Raised when a POST fails, i.e. the response status isn't 2xx.
    #
    class PostFailed < StandardError; end

    #
    # Raised when a GET fails, i.e. the response status isn't 2xx.
    #
    class GetFailed < StandardError; end

    #
    # Raised when a Conditional GET fails, i.e. the response status isn't 2xx.
    #
    class ConditionalGetFailed < StandardError; end

    #
    # Raised when a PUT fails, i.e. the response status isn't 2xx.
    #
    class PutFailed < StandardError; end

    #
    # Raised when a DELETE fails, i.e. the response status isn't 2xx.
    #
    class DeleteFailed < StandardError; end

    #
    # Raised when a POST, GET, or PUT doesn't return JSON or when the returned JSON
    # doesn't parse.
    #
    class UnparseableJson < StandardError; end

    #
    # Raised when what a POST, GET, or PUT returns parses correctly but isn't an
    # Ocean resource in the proper format.
    #
    class JsonIsNoResource < StandardError; end

    #
    # Raised when a specified hyperlink doesn't exist in the resource representation.
    #
    class HyperlinkMissing < StandardError; end


    #
    # Class method to retrieve a resource. Will raise exceptions if problems occur,
    # otherwise returns the resource itself. The args are passed directly to +new+.
    #
    def self.get!(*args)
      new(*args).send :_retrieve
    end

    #
    # Class method to retrieve a resource. Will not raise exceptions if problems occur,
    # but will always return the resource itself. The args are passed directly to +new+.
    #
    def self.get(*args)
      rr = new(*args)
      x = rr.get! rescue nil
      x || rr
    end


    #
    # Instance method to GET a resource or any of its hyperlinks. Will raise exceptions
    # if they occur, otherwise will return the resource itself.
    #
    def get!(hlink=nil, args: nil)
      _retrieve unless present?
      hlink = hlink.to_s if hlink
      if !args && (!hlink || hlink == 'self')
        self
      else
        hl_data = hyperlink[hlink]
        raise HyperlinkMissing, "#{resource_type} has no #{hlink} hyperlink" unless hl_data
        RemoteResource.get!(hl_data['href'], args: args, retries: retries, backoff_time: backoff_time, 
                                             backoff_rate: backoff_rate, backoff_max: backoff_max)
      end
    end

    #
    # Instance method to GET a resource or any of its hyperlinks. Will not raise 
    # exceptions if problems occur, but will always return the resource itself.
    # A missing hyperlink, though, will always raise a HyperlinkMissing exception.
    #
    def get(hlink=nil, args: nil)
      get! rescue nil
      hlink = hlink.to_s if hlink
      if !args && (!hlink || hlink == 'self')
        self
      else
        hl_data = hyperlink[hlink]
        raise HyperlinkMissing, "#{resource_type} has no #{hlink} hyperlink" unless hl_data
        RemoteResource.get(hl_data['href'], args: args, retries: retries, backoff_time: backoff_time, 
                                            backoff_rate: backoff_rate, backoff_max: backoff_max)
      end
    end


    #
    # Instance method to do a PUT to a resource or any of its hyperlinks. Will raise exceptions
    # if they occur, otherwise will return the resource itself.
    #
    def put!(hlink=nil, args: nil, body: {})
      get!
      hlink = hlink.to_s if hlink
      if !args && (!hlink || hlink == 'self')
        _modify(body)
        self
      else
        hl_data = hyperlink[hlink]
        raise HyperlinkMissing, "#{resource_type} has no #{hlink} hyperlink" unless hl_data
        hl_res = RemoteResource.new(hl_data['href'], retries: retries, backoff_time: backoff_time, 
                                                     backoff_rate: backoff_rate, backoff_max: backoff_max)
        hl_res.send :_modify, body, args: args
        hl_res
      end
    end

    #
    # Instance method to do a PUT to a resource or any of its hyperlinks. Will not raise 
    # exceptions if they occur, but will always return the resource itself.
    # A missing hyperlink, though, will always raise a HyperlinkMissing exception.
    #
    def put(hlink=nil, args: nil, body: {})
      get
      hlink = hlink.to_s if hlink
      if !args && (!hlink || hlink == 'self')
        _modify(body) rescue nil
        self
      else
        hl_data = hyperlink[hlink]
        raise HyperlinkMissing, "#{resource_type} has no #{hlink} hyperlink" unless hl_data
        hl_res = RemoteResource.new(hl_data['href'], retries: retries, backoff_time: backoff_time, 
                                                     backoff_rate: backoff_rate, backoff_max: backoff_max)
        hl_res.send :_modify, body, args: args
        hl_res
      end
    end


    #
    # Instance method to do a POST to a resource or any of its hyperlinks. Will raise exceptions
    # if they occur, otherwise will return the resource itself.
    #
    def post!(hlink=nil, args: nil, body: {})
      get!
      hlink = (hlink || !args && 'self').to_s
      hl_data = hyperlink[hlink]
      raise HyperlinkMissing, "#{resource_type} has no #{hlink} hyperlink" unless hl_data
      _create(hl_data['href'], body, args: args)
    end

    #
    # Instance method to do a POST to a resource or any of its hyperlinks. Will not raise 
    # exceptions if they occur, but will always return the resource itself.
    # A missing hyperlink, though, will always raise a HyperlinkMissing exception.
    #
    def post(hlink=nil, args: nil, body: {})
      get
      hlink = (hlink || !args && 'self').to_s
      hl_data = hyperlink[hlink]
      raise HyperlinkMissing, "#{resource_type} has no #{hlink} hyperlink" unless hl_data
      _create(hl_data['href'], body, args: args) rescue nil
    end


    #
    # Instance method to do a DELETE to a resource or any of its hyperlinks. Will raise exceptions
    # if they occur, otherwise will return the resource itself.
    #
    def delete!(hlink=nil, args: nil)
      get!
      hlink = (hlink || 'self').to_s
      hl_data = hyperlink[hlink]
      raise HyperlinkMissing, "#{resource_type} has no #{hlink} hyperlink" unless hl_data
      _destroy(hl_data['href'], args: args)
      self
    end

    #
    # Instance method to do a DELETE to a resource or any of its hyperlinks. Will not raise 
    # exceptions if they occur, but will always return the resource itself.
    # A missing hyperlink, though, will always raise a HyperlinkMissing exception.
    #
    def delete(hlink=nil, args: nil)
      get
      hlink = (hlink || 'self').to_s
      hl_data = hyperlink[hlink]
      raise HyperlinkMissing, "#{resource_type} has no #{hlink} hyperlink" unless hl_data
      _destroy(hl_data['href'], args: args) rescue nil
      self
    end


    #
    # If the resource is present and has received an ETag in previous requests,
    # will perform a Conditional GET to update the local representation. If the resource
    # isn't present or has no ETag, a normal +#get!+ will be done. If no exception is
    # raised, the resource itself is returned.
    #
    def refresh!
      if present? && etag.present?
        _conditional_get || self
      else
        get!
      end
    end

    #
    # If the resource is present and has received an ETag in previous requests,
    # will perform a Conditional GET to update the local representation. If the resource
    # isn't present or has no ETag, a normal +#get+ will be done. The resource will
    # always be returned.
    #
    def refresh
      if present? && etag.present?
        (_conditional_get rescue nil) || self
      else
        get
      end
    end


    private

    attr_accessor :present
    attr_writer :raw, :resource, :resource_type, :status, :headers, :status_message, :response
    attr_writer :etag, :collection


    def _credentials(rr)
      if rr.credentials.present? && rr.credentials != Api.credentials(API_USER, API_PASSWORD)
        [rr.credentials, rr.x_api_token]
      else
        [nil, rr.x_api_token || Api.service_token]
      end
    end


    def _retrieve
      credentials, token = _credentials(self)
      response = Api.request(Api.internalize_uri(uri), :get, args: args,
                               headers: {}, 
                               credentials: credentials, x_api_token: token,
                               retries: retries, backoff_time: backoff_time, backoff_rate: backoff_rate, 
                               backoff_max: backoff_max) do |x| 
        x                            # Remove this line,
        # _post_retrieve x           # uncomment this line,
      end
      _post_retrieve response        # and delete this line.
    end

    def _post_retrieve (response)
      return response if Api.simultaneously?
      self.response = response
      self.status = response.status
      self.status_message = response.message
      self.headers = response.headers
      raise GetFailed, "#{response.status} #{response.message}" unless response.success?
      begin
        raw = response.body
      rescue JSON::ParserError
        raise UnparseableJson
      end
      _setup raw, response
      #self
    end


    def _conditional_get
      credentials, token = _credentials(self)
      response = Api.request Api.internalize_uri(uri), :get, args: args,
                             headers: {"If-None-Match" => etag}, 
                             credentials: credentials, x_api_token: token,
                             retries: retries, backoff_time: backoff_time, backoff_rate: backoff_rate, 
                             backoff_max: backoff_max
      self.response = response
      return if response.status == 304
      self.status = response.status
      self.status_message = response.message
      self.headers = response.headers
      raise ConditionalGetFailed, "#{response.status} #{response.message}" unless response.success?
      begin
        raw = response.body
      rescue JSON::ParserError
        raise UnparseableJson
      end
      _setup raw, response
    end


    def _setup(wrapped, response)
      self.raw = wrapped
      if raw && raw.is_a?(Hash) && raw['_collection']
        self.collection = raw['_collection']['resources'].map { |wrapped| _make wrapped, response }
        self.resource_type = '_collection'
      else
        type, resource = verify_resource wrapped
        self.resource = resource
        self.resource_type = type
      end
      self.response = response
      self.status = response.status
      self.status_message = response.message
      self.headers = response.headers
      self.etag = headers['ETag']
      self.present = true
      self
    end


    def _make(wrapped, response)
      resource_type, attributes = wrapped.to_a.first
      r = Api::RemoteResource.new attributes['_links']['self']['href'],
          retries: retries, backoff_time: backoff_time, 
          backoff_rate: backoff_rate, backoff_max: backoff_max
      r.send :_setup, wrapped, response
      r
    end


    def verify_resource(wrapped)
      raise JsonIsNoResource unless wrapped.is_a? Hash
      raise JsonIsNoResource unless wrapped.size == 1
      resource_type, attributes = wrapped.to_a.first
      raise JsonIsNoResource unless attributes.is_a? Hash
      raise JsonIsNoResource unless attributes['_links'].is_a? Hash
      raise JsonIsNoResource unless attributes['_links']['self'].is_a? Hash
      raise JsonIsNoResource unless attributes['_links']['self']['href'].is_a? String
      raise JsonIsNoResource unless attributes['_links']['self']['type'].is_a? String
      [resource_type, attributes]
    end


    def _modify(body, args: nil)
      credentials, token = _credentials(self)
      response = Api.request Api.internalize_uri(uri), :put, headers: {}, body: body.to_json,
                             credentials: credentials, x_api_token: token,
                             retries: retries, backoff_time: backoff_time, backoff_rate: backoff_rate, 
                             backoff_max: backoff_max, args: args
      self.response = response
      self.status = response.status
      self.status_message = response.message
      self.headers = response.headers
      raise PutFailed, "#{response.status} #{response.message}" unless response.success?
      begin
        self.raw = response.body
      rescue JSON::ParserError
        raise UnparseableJson
      end
      type, resource = verify_resource(response.body) rescue return
      return if resource_type && type != resource_type
      self.resource = resource
      self.resource_type = type
      self.etag = headers['ETag']
      self.present = true
    end


    def _create(post_uri, body, args: nil)
      credentials, token = _credentials(self)
      response = Api.request Api.internalize_uri(post_uri), :post, headers: {}, body: body.to_json,
                             credentials: credentials, x_api_token: token,
                             retries: retries, backoff_time: backoff_time, backoff_rate: backoff_rate, 
                             backoff_max: backoff_max, args: args
      self.response = response
      self.status = response.status
      self.status_message = response.message
      self.headers = response.headers
      raise PostFailed, "#{response.status} #{response.message}" unless response.success?
      begin
        raw = response.body
      rescue JSON::ParserError
        raise UnparseableJson
      end
      type, resource = verify_resource(response.body)
      created = RemoteResource.new(post_uri, retries: retries, backoff_time: backoff_time, 
                                             backoff_rate: backoff_rate, backoff_max: backoff_max)
      created.send :_setup, raw, response
      created.send :etag=, nil
      created
    end


    def _destroy(delete_uri, args: nil)
      credentials, token = _credentials(self)
      response = Api.request Api.internalize_uri(delete_uri), :delete, headers: {},
                             credentials: credentials, x_api_token: token,
                             retries: retries, backoff_time: backoff_time, backoff_rate: backoff_rate, 
                             backoff_max: backoff_max, args: args
      self.response = response
      self.status = response.status
      self.status_message = response.message
      self.headers = response.headers
      raise DeleteFailed, "#{response.status} #{response.message}" unless response.success?
    end

  end
end

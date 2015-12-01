module OceanApplicationController

  #
  # Sets the default URL generation options to the HTTPS protocol, and
  # the host to the OCEAN_API_HOST, that is, to the external URL of the
  # Ocean API. We always generate external URIs, even for internal calls.
  # It's the responsibility of the other service to rewrite external
  # to internal URIs when calling the internal API point.
  #
  def default_url_options(options = nil)
    { :protocol => "https", :host => OCEAN_API_HOST }
  end


  #
  # Ensures that there is an +X-API-Token+ HTTP header in the request.
  # Stores the token in @x_api_token for use during authorisation of the
  # current controller action. If there's no +X-API-Token+ header, the
  # request is aborted and an API error with status 400 is returned.
  #
  # 400 error responses will always contain a body with error information
  # explaining the API error:
  #
  #  {"_api_error": ["X-API-Token missing"]}
  #
  # or
  #
  #  {"_api_error": ["Authentication expired"]}
  #
  def require_x_api_token
    return true if ENV['NO_OCEAN_AUTH']
    @x_api_token = request.headers['X-API-Token']
    Thread.current[:x_api_token] = @x_api_token
    @x_metadata = request.headers['X-Metadata']
    @x_metadata = @x_metadata.to_s[0, 128] if @x_metadata
    Thread.current[:metadata] = @x_metadata
    return true if @x_api_token.present?
    logger.info "X-API-Token missing"
    render_api_error 400, "X-API-Token missing"
    expires_in 0, must_revalidate: true
    false
  end



  #
  # Class variable to hold any extra controller actions defined in the
  # +ocean_resource_controller+ declaration in the resource controller.
  #
  @@extra_actions = {}


  #
  # Performs authorisation of the current action. Returns true if allowed,
  # false if not. Calls the Auth service using a +GET+, which means previous
  # authorisations using the same token and args will be cached in Varnish.
  #
  def authorize_action
    return true if ENV['NO_OCEAN_AUTH']
    # Obtain any nonstandard actions
    @@extra_actions[controller_name] ||= begin
      extra_actions
    rescue NameError => e
      {}
    end
    # Create a query string and call Auth
    qs = Api.authorization_string(@@extra_actions, controller_name, action_name)
    response = Api.permitted?(@x_api_token, query: qs)
    if response.status == 200
      a = response.body['authentication']
      @auth_api_user_id = a['user_id']  # Deprecate and remove
      @auth_api_user_uri = a['_links']['creator']['href']  # Keep
      Thread.current[:username] = a['username']
      @right_restrictions = a['right']
      params['_right_restrictions'] = @right_restrictions if @right_restrictions
      @group_names = a['group_names'].to_set if a['group_names']
      return true
    end
    error_messages = response.body['_api_error']
    render_api_error response.status, *error_messages
    expires_in 0, must_revalidate: true
    false
  end


  #
  # Updates +created_by+ and +updated_by+ to the ApiUser for which the current request
  # is authorised. The attributes can be declared either String (recommended) or
  # Integer (deprecated). If String, they will be set to the URI of the ApiUser. (If
  # Integer, to their internal SQL ID.)
  #
  def set_updater(obj)
    id_or_uri = obj.created_by.is_a?(Integer) ? @auth_api_user_id : @auth_api_user_uri
    obj.created_by = id_or_uri if obj.created_by.blank? || obj.created_by == 0
    obj.updated_by = id_or_uri
  end


  #
  # Renders an API level error. The body will be a JSON hash with a single key, 
  # +_api_error+. The value is an array containing the +messages+.
  #
  #  render_api_error(500, "An unforeseen error occurred")
  #
  # results in a response with HTTP status 500 and the following body:
  #
  #  {"_api_error": ["An unforeseen error occurred"]}
  #
  # Resource consumers should always examine the body when an error is returned,
  # as +_api_error+ always will give additional information which may be required
  # to process the error properly.
  #
  def render_api_error(status_code, *messages)
    render json: {_api_error: messages}, status: status_code
  end

  #
  # Renders a +HEAD+ response with HTTP status 204 No Content.
  #
  def render_head_204
    render nothing: true, status: 204 , content_type: 'application/json'
  end

  #
  # Renders a HTTP 422 Unprocessable Entity response with a body enumerating
  # each invalid Rails resource attribute and all their errors. This is usually
  # done in response to detecting a resource is invalid during +POST+ (create) and
  # +PUT/PATCH+ (update). E.g.:
  #
  #  {"name": ["must be specified"],
  #   "email": ["must be specified", "must contain a @ character"]}
  #
  # The messages are intended for presentation to an end user.
  #
  # The keyword argument +except+, if present, must be a string, symbol or an
  # array of strings or symbols and will suppress error information for the
  # enumerated attributes of the same names. This is sometimes useful when internal
  # attributes which never appear in external resource representations depend on
  # user-provided data, such as password hashes and salts.
  #
  def render_validation_errors(r, except: [])
    except = [except] unless except.is_a?(Array)
    except = except.collect(&:to_sym)
    render json: r.errors.messages.except(*except), status: 422
  end

  #
  # This is the main rendering function in Ocean. The argument +x+ can be a resource
  # or a collection of resources (which need not be of the same type).
  #
  # The keyword arg +new+, if true, sets the response HTTP status to 201 and also adds
  # a +Location+ HTTP header with the URI of the resource.
  #
  # Rendering is done using partials only. These should by convention be located in
  # their standard position, begin with an underscore, etc. The +ocean+ gem generator
  # for resources creates a partial in the proper location.
  #
  def api_render(x, new: false, href: url_for(params), override_partial: false)
    if !x.is_a?(Array) && !(defined?(ActiveRecord) && x.is_a?(ActiveRecord::Relation))
      partial = override_partial || x.to_partial_path
      if new
        render partial: partial, object: x, status: 201, location: x
      else
        render partial: partial, object: x
      end
      return
    else
      resources = x.dup.collect { |m| render_to_string(partial: m.to_partial_path,
                                                   locals: {m.class.model_name.i18n_key => m}) }
      count = resources.count
      total_count = x.respond_to?(:unscope) ? x.unscope(:limit, :offset).count : count
      attrs = {count: count,
               total_count: total_count
              }
      links = {}
      if href
        links['self'] =  {href: href, type: 'application/json'}
        if params[:page]
          page = params[:page].to_i
          page_size = params[:page_size].to_i || x.collection_page_size
          total_pages = (total_count.to_f / page_size.to_f).ceil
          last_page = total_pages - 1
          prev_page = page > 0 && page - 1
          next_page = page < last_page && page + 1
          links['first_page'] = {href: url_for(params.merge(page: 0)), type: 'application/json'}
          links['last_page'] = {href: url_for(params.merge(page: last_page)), type: 'application/json'}
          links['previous_page'] = {href: url_for(params.merge(page: prev_page)), type: 'application/json'} if prev_page
          links['next_page'] = {href: url_for(params.merge(page: next_page)), type: 'application/json'} if next_page
        end
      end

      attrs['_links'] = links if links
      attrs['page'] = page if page
      attrs['page_size'] = page_size if page_size
      attrs['total_pages'] = total_pages if total_pages

      render text: '{"_collection":{"resources":[' + resources.join(',') + ']' +
        (attrs.collect do |k, v|
           ',"' + k.to_s + '":' + v.to_json
         end).join('') +
        '}}'
    end
  end


  #
  # Filters away all non-accessible attributes from params. Thus, we still are
  # using pre-Rails 4.0 protected attributes. This will eventually be replaced
  # by strong parameters. Takes a class and returns a new hash containing only
  # the model attributes which may be modified.
  #
  def filtered_params(klass)
    result = {}
    params.each do |k, v|
      result[k] = v if klass.accessible_attributes.include?(k)
    end
    result
  end


  #
  # Cache values for collections. Accepts a class, a scope, or an array. 
  # The cache value is based on three components: 
  #   (1) the name of the class, 
  #   (2) the number of members in the collection, and 
  #   (3) the modification time of the last updated member.
  # If an array is given, the class of the first member will be used to
  # create a scope. If the array is empty, the optional second argument
  # will be used as the class indicator.
  #
  def collection_etag(coll, klass_name="_unknown_")
    if coll.is_a? Array
      return { etag: "#{klass_name}:0:0" } if coll == []
      # Construct a new scope and fall through
      coll = coll[0].class.where(id: coll.collect(&:id))
    end
    coll = add_right_restrictions(coll, @right_restrictions)
    klass = coll.name.constantize # Force a load of the class (for secondary collections)
    timestamp = klass.update_timestamp || klass.create_timestamp
    if (timestamp)
      last_item = coll.reorder(timestamp).last
      last_updated = last_item ? last_item.send(timestamp).utc : 0
    else
      last_updated = 0
    end
    { etag: "#{coll.name}:#{coll.count}:#{last_updated}" }
  end


  #
  # This method finds the other resource for connect/disconnect, given the
  # value of the param +href+, which should be a complete resource URI.
  #
  # Renders API errors if the +href+ arg is missing, can't be parsed, or
  # the resource can't be found.
  #
  # Sets @connectee_class to the class of the resource pointed to by +href+,
  # and @connectee to the resource itself.
  #
  def find_connectee
    href = params[:href]
    render_api_error(422, "href query arg is missing") and return if href.blank?
    begin
      routing = Rails.application.routes.recognize_path(href)
    rescue ActionController::RoutingError
      render_api_error(422, "href query arg isn't parseable")
      return
    end
    @connectee_class = routing[:controller].classify.constantize
    @connectee = @connectee_class.find_by_id(routing[:id])
    render_api_error(404, "Resource to connect not found") and return unless @connectee
    true
  end

end

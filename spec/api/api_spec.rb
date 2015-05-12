require 'spec_helper'

require 'base64'


describe Api, :type => :request do

  describe ".internalize_uri" do

    it "should convert an external HTTPS URI to an internal HTTP one" do
      expect(Api.internalize_uri("#{OCEAN_API_URL}/v3/foo/bar/baz", "master")).to eq "#{INTERNAL_OCEAN_API_URL}/v3/foo/bar/baz"
      expect(Api.internalize_uri("#{OCEAN_API_URL}/v3/foo/bar/baz", "staging")).to eq "#{INTERNAL_OCEAN_API_URL}/v3/foo/bar/baz"
      expect(Api.internalize_uri("#{OCEAN_API_URL}/v3/foo/bar/baz", "prod")).to eq "#{INTERNAL_OCEAN_API_URL}/v3/foo/bar/baz"
    end

  end

  
  it "should have a class method to return the API version for a service" do
    expect(Api.version_for(:auth)).to match /v[0-9]+/
  end



  it ".decode_credentials should be able to decode what .credentials produces" do
    expect(Api.decode_credentials(Api.credentials("foo", "bar"))).to eq ["foo", "bar"]
  end

  it ".encode_credentials should encode username and password into Base64 form" do
    expect(Api.credentials("myuser", "mypassword")).to eq(
      ::Base64.strict_encode64("myuser:mypassword")
    )
  end

  it ".decode_credentials should decode username and password from Base64" do
    expect(Api.decode_credentials(::Base64.strict_encode64("myuser:mypassword"))).to eq( 
      ['myuser', 'mypassword']
    )
  end

  it ".decode_credentials, when given nil, should return empty credentials" do
    expect(Api.decode_credentials(nil)).to eq ['', '']
  end
  
  
  describe ".permitted?" do

    it "should handle args" do
      allow(Api).to receive(:request).
        with("/v1/authentications/some-client-token", :get, args: {:query=>"abcdef"}).
        and_return(double(:status => 200))
      expect(Api.permitted?('some-client-token', query: "abcdef").status).to eq 200
    end
    
    it "should return a response with a status of 404 if the token is unknown" do
      allow(Api).to receive(:request).
        with("/v1/authentications/some-client-token", :get, args: {}).
        and_return(double(:status => 404))
      expect(Api.permitted?('some-client-token').status).to eq 404
    end
    
    it "should return a response with a status of 400 if the authentication has expired" do
      allow(Api).to receive(:request).
        with("/v1/authentications/some-client-token", :get, args: {}).
        and_return(double(:status => 400))
      expect(Api.permitted?('some-client-token').status).to eq 400
    end    
  
    it "should return a response with a status of 403 if the operation is denied" do
      allow(Api).to receive(:request).
        with("/v1/authentications/some-client-token", :get, args: {}).
        and_return(double(:status => 403))
      expect(Api.permitted?('some-client-token').status).to eq 403
    end
    
    it "should return a response with a status of 200 if the operation is authorized" do
      allow(Api).to receive(:request).
        with("/v1/authentications/some-client-token", :get, args: {}).
        and_return(double(:status => 200))
      expect(Api.permitted?('some-client-token').status).to eq 200
    end
  end


  describe "class method authorization_string" do

    it "should take the extra actions, the controller name and an action name" do
      expect(Api.authorization_string({}, "fubars", "show")).to be_a(String)
    end

    it "should take an optional app and an optional context" do
      expect(Api.authorization_string({}, "fubars", "show", "some_app", "some_context")).to be_a(String)
    end

    it "should put the app and context in the two last positions" do
      qs = Api.authorization_string({}, "fubars", "show", "some_app", "some_context").split(':')
      expect(qs[4]).to eq 'some_app'
      expect(qs[5]).to eq 'some_context'
    end

    it "should replace a blank app or context with asterisks" do
      qs = Api.authorization_string({}, "fubars", "show", nil, " ").split(':')
      expect(qs[4]).to eq '*'
      expect(qs[5]).to eq '*'
    end

    it "should take an optional service name" do
      expect(Api.authorization_string({}, "fubars", "show", "*", "*", "foo")).to eq "foo:fubars:self:GET:*:*"
    end

    it "should default the service name to APP_NAME" do
      expect(Api.authorization_string({}, "fubars", "show", "*", "*")).to eq "#{APP_NAME}:fubars:self:GET:*:*"
    end

    it "should return a string of six colon-separated parts" do
      qs = Api.authorization_string({}, "fubars", "show")
      expect(qs).to be_a(String)
      expect(qs.split(':').length).to eq 6
    end

    it "should use the controller name as the resource name" do
      qs = Api.authorization_string({}, "fubars", "show", nil, nil, 'foo').split(':')
      expect(qs[1]).to eq "fubars"
    end
  end


  describe "class method map_authorization" do

    it "should return an array of two strings" do
      m = Api.map_authorization({}, "fubars", "show")
      expect(m).to be_an(Array)
      expect(m.length).to eq 2
      expect(m[0]).to be_a(String)
      expect(m[1]).to be_a(String)
    end

    it "should translate 'show'" do
      expect(Api.map_authorization({}, "fubars", "show")).to eq ["self", "GET"]
    end

    it "should translate 'index'" do
      expect(Api.map_authorization({}, "fubars", "index")).to eq ["self", "GET*"]
    end

    it "should translate 'create'" do
      expect(Api.map_authorization({}, "fubars", "create")).to eq ["self", "POST"]
    end

    it "should translate 'update'" do
      expect(Api.map_authorization({}, "fubars", "update")).to eq ["self", "PUT"]
    end

    it "should translate 'destroy'" do
      expect(Api.map_authorization({}, "fubars", "destroy")).to eq ["self", "DELETE"]
    end

    it "should translate 'connect'" do
      expect(Api.map_authorization({}, "fubars", "connect")).to eq ["connect", "PUT"]
    end

    it "should translate 'disconnect'" do
      expect(Api.map_authorization({}, "fubars", "disconnect")).to eq ["connect", "DELETE"]
    end

    it "should raise an error for unknown actions" do
      expect { Api.map_authorization({}, "fubars", "blahonga") }.to raise_error
    end

    it "should insert the extra_action data appropriately" do
      expect(Api.map_authorization({'fubars' => {'blahonga_create' => ['blahonga', 'POST']}}, 
                             "fubars", "blahonga_create")).
        to eq ['blahonga', 'POST']
    end
  end
     
  
  describe ".adorn_basename" do

    before :all do
      @local_ip = UDPSocket.open {|s| s.connect("64.233.187.99", 1); s.addr.last}.gsub('.', '-')
    end

    it "should return a string" do
      expect(Api.adorn_basename("SomeBaseName")).to be_a String
    end

    it "should return a string containing the basename" do
      expect(Api.adorn_basename("SomeBaseName")).to include "SomeBaseName"
    end

    it "should return a string containing the Chef environment" do
      expect(Api.adorn_basename("SomeBaseName", chef_env: "zuul")).to include "zuul"
    end

    it "should add only the Chef env if the Rails env is production" do
      expect(Api.adorn_basename("Q", chef_env: "prod", rails_env: 'production')).to eq     "Q_prod"
      expect(Api.adorn_basename("Q", chef_env: "staging", rails_env: 'production')).to eq  "Q_staging"
      expect(Api.adorn_basename("Q", chef_env: "master", rails_env: 'production')).to eq   "Q_master"
    end

    it "should add IP and rails_env if the chef_env is 'dev' or 'ci' or if rails_env isn't 'production'" do
      expect(Api.adorn_basename("Q", chef_env: "dev",  rails_env: 'development')).to eq    "Q_dev_#{@local_ip}_development"
      expect(Api.adorn_basename("Q", chef_env: "dev",  rails_env: 'test')).to eq           "Q_dev_#{@local_ip}_test"
      expect(Api.adorn_basename("Q", chef_env: "dev",  rails_env: 'production')).to eq     "Q_dev_#{@local_ip}_production"
      expect(Api.adorn_basename("Q", chef_env: "ci",   rails_env: 'development')).to eq    "Q_ci_#{@local_ip}_development"
      expect(Api.adorn_basename("Q", chef_env: "ci",   rails_env: 'test')).to eq           "Q_ci_#{@local_ip}_test"
      expect(Api.adorn_basename("Q", chef_env: "ci",   rails_env: 'production')).to eq     "Q_ci_#{@local_ip}_production"
      expect(Api.adorn_basename("Q", chef_env: "master", rails_env: 'development')).to eq  "Q_master_#{@local_ip}_development"
      expect(Api.adorn_basename("Q", chef_env: "master", rails_env: 'test')).to eq         "Q_master_#{@local_ip}_test"
      expect(Api.adorn_basename("Q", chef_env: "staging", rails_env: 'development')).to eq "Q_staging_#{@local_ip}_development"
      expect(Api.adorn_basename("Q", chef_env: "staging", rails_env: 'test')).to eq        "Q_staging_#{@local_ip}_test"
      expect(Api.adorn_basename("Q", chef_env: "staging", rails_env: 'production')).to eq  "Q_staging"
      expect(Api.adorn_basename("Q", chef_env: "prod", rails_env: 'development')).to eq    "Q_prod_#{@local_ip}_development"
      expect(Api.adorn_basename("Q", chef_env: "prod", rails_env: 'test')).to eq           "Q_prod_#{@local_ip}_test"
    end

    it "should leave out the basename if :suffix_only is true" do
      expect(Api.adorn_basename("Q", chef_env: "prod", rails_env: 'production', suffix_only: true)).
        to eq "_prod"
      expect(Api.adorn_basename("Q", chef_env: "prod", rails_env: 'development', suffix_only: true)).
        to eq "_prod_#{@local_ip}_development"
    end
  end


  describe ".basename_suffix" do

    it "should return a string" do
      expect(Api.basename_suffix).to be_a String
    end
  end


  describe ".escape" do

    it "should escape the backslash (\)" do
      expect(Api.escape("\\")).to eq "%5C"
    end

    it "should escape the pipe (|)" do
      expect(Api.escape("|")).to eq "%7C"
    end

    it "should escape the backslash (\)" do
      expect(Api.escape("?")).to eq "%3F"
    end

    it "should escape the left bracket" do
      expect(Api.escape("[")).to eq "%5B"
    end

    it "should escape the right bracket" do
      expect(Api.escape("]")).to eq "%5D"
    end

    it "should not escape parens" do
      expect(Api.escape("()")).to eq "()"
    end

    it "should not escape dollar signs" do
      expect(Api.escape("$")).to eq "$"
    end

    it "should not escape slashes (/)" do
      expect(Api.escape("/")).to eq "/"
    end

    it "should not escape plusses (+)" do
      expect(Api.escape("+")).to eq "+"
    end

    it "should not escape asterisks" do
      expect(Api.escape("*")).to eq "*"
    end

    it "should not escape full stops" do
      expect(Api.escape(".")).to eq "."
    end

    it "should not escape hyphens" do
      expect(Api.escape("-")).to eq "-"
    end

    it "should not escape underscores" do
      expect(Api.escape("_")).to eq "_"
    end

    it "should not escape letters or numbers" do
      expect(Api.escape("AaBbCc123")).to eq "AaBbCc123"
    end
  end


  describe ".credentials" do

    it "should take two args and encode them" do
      expect(Api.credentials 'foo', 'bar').to eq "Zm9vOmJhcg=="
    end

    it "should produce a result which can be decoded" do
      expect(Api.decode_credentials(Api.credentials 'foo', 'bar')).
        to eq ["foo", "bar"]
    end

    it "should take no args and default to API_USER and API_PASSWORD" do
      expect(Api.decode_credentials(Api.credentials)).
        to eq [API_USER, API_PASSWORD]
    end

    it "should not allow only one arg" do
      expect { Api.credentials 'foo' }.to raise_error
    end
  end


  it "Api.send_mail should send email asynchronously" do
    expect(Api).to receive(:service_token).and_return("fakeissimo")
    stub_request(:post, "http://forbidden.example.com/v1/mails").
         with(:body => "{\"from\":\"charles.anka@example.com\",\"to\":\"kajsa.anka@example.com\",\"subject\":\"Test mail\",\"plaintext\":\"Hello world.\",\"html\":null,\"plaintext_url\":null,\"html_url\":null,\"substitutions\":null}",
              :headers => {'Accept'=>'application/json', 'Content-Type'=>'application/json', 'User-Agent'=>'Ocean', 'X-Api-Token'=>'fakeissimo'}).
         to_return(:status => 200, :body => "", :headers => {})    
    Api.send_mail from: "charles.anka@example.com", to: "kajsa.anka@example.com",
                  subject: "Test mail", plaintext: "Hello world."
  end


  describe ".async_job_body" do

    before :each do
      allow(Api).to receive(:credentials).and_return "the-creds"
      allow(Api).to receive(:service_token).and_return "the-token"
      @mandatory = {"credentials"=>"the-creds", "token"=>"the-token", "steps"=>[]}
    end

    it "should return a hash" do
      expect(Api.async_job_body()).to eq @mandatory
    end

    it "should take a :credentials keyword" do
      expect(Api.async_job_body(credentials: "xxx")).
        to eq @mandatory.merge({"credentials"=>"xxx"})
    end

    it "should take a :token keyword" do
      expect(Api.async_job_body(token: "yyy")).
        to eq @mandatory.merge({"token"=>"yyy"})
    end

    it "should take a :steps keyword" do
      expect(Api.async_job_body steps: []).
        to eq @mandatory.merge({"steps"=>[]})
    end

    it "should take a :default_step_time keyword" do
      expect(Api.async_job_body(default_step_time: 10)).
        to eq @mandatory.merge({"default_step_time"=>10})
    end

    it "should take a :default_poison_limit keyword" do
      expect(Api.async_job_body(default_poison_limit: 4)).
        to eq @mandatory.merge({"default_poison_limit"=>4})
    end

    it "should take a :max_seconds_in_queue keyword" do
      expect(Api.async_job_body(max_seconds_in_queue: 600)).
        to eq @mandatory.merge({"max_seconds_in_queue"=>600})
    end

    it "should take a :poison_email keyword" do
      expect(Api.async_job_body(poison_email: "admin@example.com")).
        to eq @mandatory.merge({"poison_email"=>"admin@example.com"})
    end

    it "should take an optional uri and construct a steps array" do
      expect(Api.async_job_body("http://foo.com")).
        to eq @mandatory.merge({"steps"=>[{"url"=>"http://foo.com", "method"=>"GET"}]})
    end

    it "should allow the uri method to be overridden using an optional method" do
      expect(Api.async_job_body("http://foo.com", :delete)).
        to eq @mandatory.merge({"steps"=>[{"url"=>"http://foo.com", "method"=>"DELETE"}]})
    end

    it "should let explicit steps override any uri and method" do
      expect(Api.async_job_body("http://foo.com", steps: [])).
        to eq @mandatory.merge({"steps"=>[]})
    end

    it "should prepend the INTERNAL_OCEAN_API_URL to the href if it starts with /" do
      expect(Api.async_job_body("/v1/thingies")).
        to eq @mandatory.merge({"steps"=>[{"url"=>"#{INTERNAL_OCEAN_API_URL}/v1/thingies",
                                           "method"=>"GET"}]})
    end

    it "should add the :body keyword if there is one to the terse uri and POST method form" do
      expect(Api.async_job_body("/v1/thingies", :post, body: {})).
        to eq @mandatory.merge({"steps"=>[{"url"=>"#{INTERNAL_OCEAN_API_URL}/v1/thingies",
                                           "method"=>"POST",
                                           "body"=>{}}]})
    end

    it "should add the :body keyword if there is one to the terse uri and PUT method form" do
      expect(Api.async_job_body("/v1/thingies", :put, body: {})).
        to eq @mandatory.merge({"steps"=>[{"url"=>"#{INTERNAL_OCEAN_API_URL}/v1/thingies",
                                           "method"=>"PUT",
                                           "body"=>{}}]})
    end

    it "should not add the :body keyword for a GET" do
      expect(Api.async_job_body("/v1/thingies", :get, body: {})).
        to eq @mandatory.merge({"steps"=>[{"url"=>"#{INTERNAL_OCEAN_API_URL}/v1/thingies",
                                           "method"=>"GET"}]})
    end

    it "should not add the :body keyword for a DELETE" do
      expect(Api.async_job_body("/v1/thingies", :delete, body: {})).
        to eq @mandatory.merge({"steps"=>[{"url"=>"#{INTERNAL_OCEAN_API_URL}/v1/thingies",
                                           "method"=>"DELETE"}]})
    end
  end


  describe ".run_async_job" do

    it "should take the same args as .async_job_body and run an AsyncJob, returning the response" do
      allow(Api).to receive(:service_token).and_return "the-token"
      allow(Api).to receive(:credentials).and_return "the-creds"
      stub_request(:post, "http://forbidden.example.com/v1/async_jobs").
         with(:body => {"steps"=>[{"url"=>"http://forbidden.example.com/v1/foos/1",
                                   "method"=>"DELETE"}],
                        "credentials"=>"the-creds", 
                        "token"=>"the-token"}.to_json,
              :headers => {'Accept'=>'application/json', 
                           'Content-Type'=>'application/json', 
                           'User-Agent'=>'Ocean', 
                           'X-Api-Token'=>'the-token'}).
         to_return(:status => 200, :body => "", :headers => {})
      expect(Api.run_async_job("/v1/foos/1", :delete)).to be_a Api::Response
    end

    it "should handle a PUT body" do
      allow(Api).to receive(:service_token).and_return "the-token"
      allow(Api).to receive(:credentials).and_return "the-creds"
      stub_request(:post, "#{INTERNAL_OCEAN_API_URL}/v1/async_jobs").
         with(:body => {"steps"=>[{"url"=>"#{INTERNAL_OCEAN_API_URL}/v1/foos/1",
                                   "method"=>"PUT",
                                   "body"=>{"x"=>1, "y"=>2}}],
                        "credentials"=>"the-creds", 
                        "token"=>"the-token"}.to_json,
              :headers => {'Accept'=>'application/json', 
                           'Content-Type'=>'application/json', 
                           'User-Agent'=>'Ocean', 
                           'X-Api-Token'=>'the-token'}).
         to_return(:status => 200, :body => "", :headers => {})
      Api.run_async_job("/v1/foos/1", :put, body: {"x"=>1, "y"=>2})
    end

    it "should handle a POST body" do
      allow(Api).to receive(:service_token).and_return "the-token"
      allow(Api).to receive(:credentials).and_return "the-creds"
      stub_request(:post, "#{INTERNAL_OCEAN_API_URL}/v1/async_jobs").
         with(:body => {"steps"=>[{"url"=>"#{INTERNAL_OCEAN_API_URL}/v1/foos/1",
                                   "method"=>"POST",
                                   "body"=>{"x"=>1, "y"=>2}}],
                        "credentials"=>"the-creds", 
                        "token"=>"the-token"}.to_json,
              :headers => {'Accept'=>'application/json', 
                           'Content-Type'=>'application/json', 
                           'User-Agent'=>'Ocean', 
                           'X-Api-Token'=>'the-token'}).
         to_return(:status => 201, :body => "", :headers => {})
      Api.run_async_job("/v1/foos/1", :post, body: {"x"=>1, "y"=>2})
    end

    it "should handle a precomputed job, not calling .async_job_body" do
      allow(Api).to receive(:service_token).and_return "the-token"
      stub_request(:post, "http://forbidden.example.com/v1/async_jobs").
         with(:body => "{\"steps\":[]}",
              :headers => {'Accept'=>'application/json', 
                           'Content-Type'=>'application/json', 
                           'User-Agent'=>'Ocean', 
                           'X-Api-Token'=>'the-token'}).
         to_return(:status => 200, :body => "", :headers => {})
      Api.run_async_job(job: {'steps'=>[]})
    end

    it "should not should not block general exceptions" do
      expect(Api).to receive(:service_token).and_raise ZeroDivisionError, "Woo"
      expect { Api.run_async_job(job: {'steps'=>[]}) }.to raise_error ZeroDivisionError, "Woo"
    end

    it "if there is a block, should yield any TimeoutError to it" do
      expect(Api).to receive(:service_token).and_raise Api::TimeoutError, "oh dear"
      expect { |b| Api.run_async_job(job: {'steps'=>[]}, &b) }.to yield_with_args(Exception)
    end

    it "if there is a block, should yield any NoResponseError to it" do
      expect(Api).to receive(:service_token).and_raise Api::NoResponseError, "oh my"
      expect { |b| Api.run_async_job(job: {'steps'=>[]}, &b) }.to yield_with_args(Exception)
    end

    it "if there is no block, should not intercept TimeoutError" do
      expect(Api).to receive(:service_token).and_raise Api::TimeoutError, "oh dear"
      expect { |b| Api.run_async_job(job: {'steps'=>[]}) }.to raise_error Api::TimeoutError, "oh dear"
    end

    it "if there is no block, should not intercept NoResponseError" do
      expect(Api).to receive(:service_token).and_raise Api::NoResponseError, "oh my"
      expect { |b| Api.run_async_job(job: {'steps'=>[]}) }.to raise_error Api::NoResponseError, "oh my"
    end

    it "should return the value of an invoked exception handler block" do
      expect(Api).to receive(:service_token).and_raise Api::TimeoutError
      expect(Api.run_async_job("/v1/foos", :delete) { |e| 24 }).to eq 24
    end
  end


end

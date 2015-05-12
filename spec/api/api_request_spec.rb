require 'spec_helper'

describe Api, :type => :request do

  before :each do
    Api.reset_service_token
  end


  describe ".authenticate" do

    it "should raise an exception if the return status isn't 201, 400, 403, or 500" do
      stub_request(:post, "#{INTERNAL_OCEAN_API_URL}/v1/authentications").
         to_return(:status => 666, :body => "")      
      expect { Api.authenticate }.to raise_error("Authentication weirdness")
    end

    it "should set @service_token if the credentials match the service's own" do
      stub_request(:post, "#{INTERNAL_OCEAN_API_URL}/v1/authentications").
         to_return(:status => 201, :body => {'authentication'=>{'token'=>"fresh-token"}}.to_json)      
      expect(Api.authenticate API_USER, API_PASSWORD).to eq "fresh-token"
      expect(Api.instance_variable_get(:@service_token)).to eq "fresh-token"
    end

    it "should not set @service_token if the credentials are custom" do
      stub_request(:post, "#{INTERNAL_OCEAN_API_URL}/v1/authentications").
         to_return(:status => 201, :body => {'authentication'=>{'token'=>"custom-token"}}.to_json)      
      expect(Api.authenticate "user", "pw").to eq "custom-token"
      expect(Api.instance_variable_get(:@service_token)).not_to eq "custom-token"
    end
  end



  describe ".service_token" do

    it "should call Api.authenticate the first time it's called and cache the result" do
      expect(Api).to receive(:authenticate).once.and_return("a-fake-token")
      expect(Api.service_token).to eq "a-fake-token"
      expect(Api.service_token).to eq "a-fake-token"
      expect(Api.service_token).to eq "a-fake-token"
    end

    it "should be resettable" do
      expect(Api).to receive(:authenticate).twice.and_return("a-fake-token")
      expect(Api.service_token).to eq "a-fake-token" # This one yields the first call
      expect(Api.service_token).to eq "a-fake-token"
      expect(Api.service_token).to eq "a-fake-token"
      Api.reset_service_token
      expect(Api.service_token).to eq "a-fake-token" # And this one the second
      expect(Api.service_token).to eq "a-fake-token"
      expect(Api.service_token).to eq "a-fake-token"
    end
  end



  describe ".request" do

    before :each do
      allow(Object).to receive :sleep
    end

    it "should take a :x_api_token keyword arg and add an X-API-Token header" do
      stub_request(:GET, "http://the-url").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean', 
                           'X-Api-Token'=>'some-token'}).
         to_return(:status => 200)
      Api.request "http://the-url", "GET", x_api_token: "some-token"
    end


    it "should not add an X-API-Token if the :x_api_token keyword is nil" do
      stub_request(:GET, "http://the-url").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_return(:status => 200)
      Api.request "http://the-url", "GET", x_api_token: nil
    end


    it "should raise Api::TimeoutError if the request timed out" do
      stub_request(:GET, "http://the-url/").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_timeout
      expect { Api.request "the-url", "GET" }.
        to raise_error(Api::TimeoutError, "Api.request timed out")
    end


    it "should raise Api::NoResponseError if no HTTP response could be obtained" do
       stub_request(:GET, "http://the-url/").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_return(:status => 0)
      expect { Api.request "the-url", "GET" }.
        to raise_error(Api::NoResponseError, "Api.request could not obtain a response")
    end


    it "should re-authenticate and retry once when status is 400 or 419" do
      [400, 419].each do |code|
        stub_request(:GET, "http://the-url/").
          with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean', 
                            'X-Api-Token'=>'an-expired-token'}).
          to_return(:status => code)
        expect(Api).to receive(:authenticate).and_return('a-fresh-token')
        stub_request(:GET, "http://the-url/").
          with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean', 
                            'X-Api-Token'=>'a-fresh-token'}).
          to_return(:status => 200)
        Api.request "the-url", "GET", x_api_token: "an-expired-token"
        expect(Api.instance_variable_get(:@service_token)).to eq "a-fresh-token"
      end
    end


    it "should use the supplied credentials, if present, to re-authenticate and retry once when status is 400 or 419" do
      [400, 419].each do |code|
        stub_request(:GET, "http://the-url/").
          with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean', 
                            'X-Api-Token'=>'an-expired-token'}).
          to_return(:status => code)
        expect(Api).to receive(:authenticate).with("user", "pw").and_return('a-custom-token')
        stub_request(:GET, "http://the-url/").
          with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean', 
                            'X-Api-Token'=>'a-custom-token'}).
          to_return(:status => 200)
        Api.request "the-url", "GET", x_api_token: "an-expired-token", credentials: Api.credentials("user", "pw")
        expect(Api.instance_variable_get(:@service_token)).not_to eq "a-custom-token"
      end
    end


    it "should authenticate with the given credentials if present and the x_api_token is not" do
      expect(Api).to receive(:authenticate).with("user", "pw").and_return("custom-initial-token")
      stub_request(:GET, "http://the-url/").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean', 
                           'X-Api-Token'=>'custom-initial-token'}).
         to_return(:status => 200)
      Api.request "the-url", "GET", x_api_token: nil, credentials: Api.credentials("user", "pw")
    end


    it "should retry a GET when :retries was given and is an integer > 0" do
      allow(Object).to receive(:sleep)
      stub_request(:GET, "http://the-url/").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_return(status: 503).then.
         to_timeout.then.
         to_return(status: 202)
      response = Api.request "the-url", "GET", retries: 3
      expect(response.status).to eq 202
    end


    it "should not retry when :retries was given and is 0" do
      stub_request(:GET, "http://the-url/").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_return(status: 503)
      response = Api.request "the-url", "GET", retries: 0
      expect(response.status).to eq 503
    end


    it "should not retry POST even if :retries was given" do
     stub_request(:POST, "http://the-url/").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_return(status: 503).then.
         to_timeout.then.
         to_return(status: 202)
      response = Api.request "the-url", "POST", retries: 3
      expect(response.status).to eq 503
    end

    it "should not retry PUT even if :retries was given" do
      stub_request(:PUT, "http://the-url/").
        with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_return(status: 503).then.
         to_timeout.then.
         to_return(status: 202)
      response = Api.request "the-url", "PUT", retries: 3
      expect(response.status).to eq 503
    end

    it "should not retry DELETE even if :retries was given" do
      stub_request(:DELETE, "http://the-url/").
        with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_return(status: 503).then.
         to_timeout.then.
         to_return(status: 202)
      response = Api.request "the-url", "DELETE", retries: 3
      expect(response.status).to eq 503
    end


    it "when retrying, should intercept TimeoutError and NoResponseError except during the last retry" do
      allow(Object).to receive(:sleep)
      stub_request(:GET, "http://the-url/").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_timeout.then.
         to_timeout.then.
         to_return(status: 200)
      response = Api.request "the-url", "GET", retries: 3
      expect(response.status).to eq 200
    end


    it "when retrying, should return 4xx responses" do
      allow(Object).to receive(:sleep)
      stub_request(:GET, "http://the-url/").
        with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
        to_timeout.then.
        to_return(status: 503).then.
        to_return(status: 404)
      response = Api.request "the-url", "GET", retries: 10
      expect(response.status).to eq 404
    end


    it "should sleep between retries" do
      expect(Object).to receive(:sleep).twice
      stub_request(:GET, "http://the-url/").
        with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
        to_timeout.then.
        to_return(status: 0).then.
        to_return(status: 200)
      response = Api.request "the-url", "GET", retries: 3
      expect(response.status).to eq 200
    end

    it "should backoff between retries" do
      [1, 1.9, 3.61, 6.859, 13.0321, 24.76099, 30].each { |t| expect(Object).to receive(:sleep).with(t).ordered }
      stub_request(:GET, "http://the-url/").
        with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
        to_timeout.then.
        to_return(status: 500).then.
        to_timeout.then.
        to_timeout.then.
        to_return(status: 500).then.
        to_return(status: 500).then.
        to_timeout.then.
        to_return(status: 200)
      response = Api.request "the-url", "GET", retries: 10
      expect(response.status).to eq 200
    end

    it "should not sleep between retries if backoff_time is 0" do
      expect(Object).to receive(:sleep).with(0).exactly(7).times
      stub_request(:GET, "http://the-url/").
        with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
        to_timeout.then.
        to_return(status: 500).then.
        to_timeout.then.
        to_timeout.then.
        to_return(status: 500).then.
        to_return(status: 500).then.
        to_timeout.then.
        to_return(status: 200)
      response = Api.request "the-url", "GET", retries: 10, backoff_time: 0
      expect(response.status).to eq 200
    end

    it "should accept a post-processing block and call it with response, returning what the block returnx" do
      stub_request(:get, "http://the-url/").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_return(:status => 200, :body => "", :headers => {})      
      result = Api.request("http://the-url", :get) do |response|
        raise unless response.is_a?(Api::Response)
        :postprocessing_result
      end
      expect(result).to eq :postprocessing_result
    end

    it "should add INTERNAL_OCEAN_API_URL to a URI starting with /" do
      stub_request(:get, "#{INTERNAL_OCEAN_API_URL}/v1/foos").
         to_return(:status => 200, :body => "", :headers => {})
      Api.request "/v1/foos", :get
    end

  end


  describe ".simultaneously" do

    it "should take a block and execute it during which .simultaneously? should be true" do
      expect(Api).to receive(:simultaneously?).and_call_original.exactly(3).times
      expect(Api.simultaneously?).to eq false
      Api.simultaneously do
        expect(Api.simultaneously?).to eq true
      end
      expect(Api.simultaneously?).to eq false
    end

    it "should raise an error if there is no block" do
      expect { Api.simultaneously }.to raise_error StandardError, "block required"
    end

    it "should return an array" do
      expect(Api.simultaneously {}).to eq []
    end

    it "should call the block with the array so that requests can be pushed onto it" do
      stub_request(:get, "http://foo.com/").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_return(:status => 404, :body => "{}", :headers => {})
      results = Api.simultaneously do |r| 
        r << Api.request("http://foo.com", :get)
      end
      expect(results.length).to eq 1
    end

    it "should evaluate the getter functions before returning the array" do
      stub_request(:get, "http://foo.com/").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_return(:status => 404, :body => "{}", :headers => {})
      results = Api.simultaneously do |r| 
        r << Api.request("http://foo.com", :get)
      end
      expect(results.map(&:status)).to eq [404]
    end

    it "should handle more than one parallel call" do
      stub_request(:get, "http://foo.com/").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_return(:status => 404, :body => "{}", :headers => {})
      stub_request(:get, "http://bar.com/").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_return(:status => 200, :body => "{}", :headers => {})
      stub_request(:get, "http://baz.com/").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_return(:status => 403, :body => "{}", :headers => {})
      results = Api.simultaneously do |r| 
        r << Api.request("http://foo.com", :get)
        r << Api.request("http://bar.com", :get)
        r << Api.request("http://baz.com", :get)
      end
      expect(results.map(&:status)).to eq [404, 200, 403]
    end

    it "should handle retries" do
      allow_any_instance_of(Object).to receive(:sleep)
      stub_request(:get, "http://foo.com/").
         to_return(:status => 503).then.
         to_return(:status => 0).then.
         to_return(:status => 403)
      results = Api.simultaneously do |r| 
        r << Api.request("http://foo.com", :get, retries: 2)
      end
      expect(results.map(&:status)).to eq [403]
    end

    it "should handle retries in parallel" do
      allow_any_instance_of(Object).to receive(:sleep)
      stub_request(:get, "http://foo.com/").
         to_return(:status => 503).then.
         to_return(:status => 0).then.
         to_return(:status => 403)
      stub_request(:get, "http://bar.com/").
         to_return(:status => 0).then.
         to_return(:status => 200)
      results = Api.simultaneously do |r| 
        r << Api.request("http://foo.com", :get, retries: 3)
        r << Api.request("http://bar.com", :get, retries: 3)
      end
      expect(results.map(&:status)).to eq [403, 200]
    end

    it "should memoize identical calls" do
      stub_request(:get, "http://foo.com/").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_return(:status => 200, :body => "{}", :headers => {})
      stub_request(:get, "http://bar.com/").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_return(:status => 404, :body => "{}", :headers => {})
      results = Api.simultaneously do |r| 
        r << Api.request("http://foo.com", :get)
        r << Api.request("http://bar.com", :get)
        r << Api.request("http://foo.com", :get)
      end
      expect(results.map(&:status)).to eq [200, 404, 200]
    end

    it "should not transparently re-authenticate on 400 if there is no token header" do
      stub_request(:get, "http://foo.com/").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_return(:status => 400, :body => '{"_api_error":[]}', :headers => {})
      expect(Api).not_to receive(:authenticate)
      results = Api.simultaneously do |r|
        r << Api.request("http://foo.com", :get, headers: {})
      end
      expect(results[0].status).to be 400
    end

    it "should not transparently re-authenticate on 419 if there is no token header" do
      stub_request(:get, "http://foo.com/").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_return(:status => 419, :body => '{"_api_error":[]}', :headers => {})
      expect(Api).not_to receive(:authenticate)
      results = Api.simultaneously do |r|
        r << Api.request("http://foo.com", :get, headers: {})
      end
      expect(results[0].status).to be 419
    end

    it "should transparently re-authenticate on 400 when there is a token header" do
      stub_request(:get, "http://foo.com/").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean', 
                           'X-Api-Token'=>'unknown-token'}).
         to_return(:status => 400, :body => '{"_api_error":[]}', :headers => {})

      stub_request(:post, "#{INTERNAL_OCEAN_API_URL}/v1/authentications").
         to_return(:status => 201, :body => {'authentication'=>{'token'=>"fresh-token"}}.to_json)      

      stub_request(:get, "http://foo.com/").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean'}).
         to_return(:status => 200, :body => "")

      results = Api.simultaneously do |r|
        r << Api.request("http://foo.com", :get, headers: {})
      end
      expect(results[0].status).to be 200
    end

  end

end

require 'spec_helper'

describe Api::RemoteResource, :type => :model do

  before :each do
    @good_json = {"blah"=>{
                    "_links"=>{"self"=>{"href"=>"http://example.com/v1/blahs/1",
                                        "type"=>"application/json"},
                               "quux"=>{"href"=>"http://acme.com/v1/quux/1",
                                        "type"=>"application/json"}
                              },
                    "foo" => 123,
                    "bar" => [1,2,3]
                 }}
    @successful = double success?: true, 
                         headers: {"Content-Type"=>"application/json", "ETag"=>'"FAFAFAFA"'}, 
                         body: @good_json,
                         status: 200,
                         message: "Success"
  end

  describe "new" do

    it "should be possible" do
  	  expect(Api::RemoteResource).to respond_to :new
    end

    it "should require a URI" do
      expect(Api::RemoteResource.new("http://example.com/v1/foos/2")).to be_an Api::RemoteResource
    end

    it "should take an optional content type which should default to application/json" do
      expect(Api::RemoteResource.new("foo", "application/json")).to be_an Api::RemoteResource
    end
    it "should default the content_type to application/json" do
      expect(Api::RemoteResource.new("foo").content_type).to eq "application/json"
    end

    it "should accept a :retries keyword" do
      expect(Api::RemoteResource.new("foo", retries: 4)).to be_an Api::RemoteResource
    end

    it "should accept a :backoff_time keyword" do
      expect(Api::RemoteResource.new("foo", backoff_time: 2)).to be_an Api::RemoteResource
    end

    it "should accept a :backoff_rate keyword" do
      expect(Api::RemoteResource.new("foo", backoff_rate: 3)).to be_an Api::RemoteResource
    end

    it "should accept a :backoff_max keyword" do
      expect(Api::RemoteResource.new("foo", backoff_max: 30)).to be_an Api::RemoteResource
    end

    it "should accept a :x_api_token keyword" do
      expect(Api::RemoteResource.new("foo", x_api_token: "some-custom-token")).to be_an Api::RemoteResource
    end

    it "should accept a :credentials keyword" do
      expect(Api::RemoteResource.new("foo", credentials: Api.credentials("user", "pw"))).to be_an Api::RemoteResource
    end
  end



  describe "._retrieve" do

    before :each do
      allow(Api).to receive(:service_token).and_return "totally-fake-token"
    end

    it "should call Api.request" do
      expect(Api).to receive(:request).and_return(@successful)
      Api::RemoteResource.get!("http://example.com/v1/blahs/1")
    end


    it "should use the service token if no x_api_token has been specified" do
      expect(Api).to receive(:service_token).and_return "the-service_token"
      expect(Api).to receive(:request).with("http://example.com/v1/blahs/1", :get, args: nil,
                                            :headers=>{}, 
                                            :credentials=>nil, 
                                            :x_api_token=>"the-service_token", 
                                            :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@successful)
      Api::RemoteResource.get!("http://example.com/v1/blahs/1")
    end

    it "should use the supplied x_api_token if specified" do
      expect(Api).not_to receive(:service_token)
      expect(Api).to receive(:request).with("http://example.com/v1/blahs/1", :get, args: nil, 
                                            :headers=>{}, 
                                            :credentials=>nil, 
                                            :x_api_token=>"supplied_token", 
                                            :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@successful)
      Api::RemoteResource.get!("http://example.com/v1/blahs/1", x_api_token: "supplied_token")
    end

    it "if the credentials are different from the service's own, should send them and the token" do
      expect(Api).not_to receive(:service_token)
      expect(Api).to receive(:request).with("http://example.com/v1/blahs/1", :get, args: nil, 
                                            :headers=>{}, 
                                            :credentials=>Api.credentials("user", "pw"), 
                                            :x_api_token=>"supplied_token", 
                                            :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@successful)
      Api::RemoteResource.get!("http://example.com/v1/blahs/1",
        credentials: Api.credentials("user", "pw"),
        x_api_token: "supplied_token")
    end

    it "should not send the credentials if they are the same as the service's own but should still send the token" do
      expect(Api).not_to receive(:service_token)
      expect(Api).to receive(:request).with("http://example.com/v1/blahs/1", :get, args: nil, 
                                            :headers=>{}, 
                                            :credentials=>nil, 
                                            :x_api_token=>"supplied_token", 
                                            :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@successful)
      Api::RemoteResource.get!("http://example.com/v1/blahs/1",
        credentials: Api.credentials(API_USER, API_PASSWORD),
        x_api_token: "supplied_token")
    end


    it "should set the present flag to true after a successful GET" do
      expect(Api).to receive(:request).and_return(@successful)
      expect(Api::RemoteResource.get!("http://example.com/v1/blahs/1").present?).to eq true
    end

    it "shouldn't set the present flag to true when there is an exception" do
      rr = Api::RemoteResource.new("http://example.com/v1/blahs/1")
      expect(Api).to receive(:request).and_raise ZeroDivisionError
      expect { rr.get! }.to raise_error
      expect(rr.present?).to eq false
    end

    it "shouldn't set the present flag to true if the GET wasn't successful" do
      expect(Api).to receive(:request).
        and_return(double(success?: false, status: 404, message: "Not found", headers: {}))
      rr = Api::RemoteResource.new("http://example.com/v1/blahs/1")
      expect { rr.get! }.to raise_error Api::RemoteResource::GetFailed
      expect(rr.present?).to eq false
    end


    it "should set the etag after a successful GET" do
      expect(Api).to receive(:request).and_return(@successful)
      expect(Api::RemoteResource.get!("http://example.com/v1/blahs/1").etag).to eq '"FAFAFAFA"'
    end

    it "shouldn't set etag when there is an exception" do
      rr = Api::RemoteResource.new("http://example.com/v1/blahs/1")
      expect(Api).to receive(:request).and_raise ZeroDivisionError
      expect { rr.get! }.to raise_error
      expect(rr.etag).to eq nil
    end

    it "shouldn't set the etag if the GET wasn't successful" do
      expect(Api).to receive(:request).
        and_return(double(success?: false, status: 404, message: "Not found", headers: {}))
      rr = Api::RemoteResource.new("http://example.com/v1/blahs/1")
      expect { rr.get! }.to raise_error Api::RemoteResource::GetFailed
      expect(rr.etag).to eq nil
    end


    it "should set response even if the GET wasn't successful" do
      expect(Api).to receive(:request).
        and_return(double(success?: false, status: 403, message: "Forbidden", headers: {}))
      rr = Api::RemoteResource.new("http://example.com/v1/blahs/1")
      expect { rr.get! }.to raise_error Api::RemoteResource::GetFailed
      expect(rr.response).not_to eq nil
    end

    it "should set status even if the GET wasn't successful" do
      expect(Api).to receive(:request).
        and_return(double(success?: false, status: 403, message: "Forbidden", headers: {}))
      rr = Api::RemoteResource.new("http://example.com/v1/blahs/1")
      expect { rr.get! }.to raise_error Api::RemoteResource::GetFailed
      expect(rr.status).to eq 403
    end

    it "should set status_message even if the GET wasn't successful" do
      expect(Api).to receive(:request).
        and_return(double(success?: false, status: 403, message: "Forbidden", headers: {}))
      rr = Api::RemoteResource.new("http://example.com/v1/blahs/1")
      expect { rr.get! }.to raise_error Api::RemoteResource::GetFailed
      expect(rr.status_message).to eq "Forbidden"
    end      

    it "should set headers even if the GET wasn't successful" do
      expect(Api).to receive(:request).
        and_return(double(success?: false, status: 403, message: "Forbidden", headers: {'Blah' => 'Moo'}))
      rr = Api::RemoteResource.new("http://example.com/v1/blahs/1")
      expect { rr.get! }.to raise_error Api::RemoteResource::GetFailed
      expect(rr.headers).to eq({'Blah' => 'Moo'})
    end      

    it "should raise a GetFailed if the GET wasn't successful" do
      expect(Api).to receive(:request).
        and_return(double(success?: false, status: 404, message: "Not Found", headers: {}))
      expect { Api::RemoteResource.get!("http://example.com/v1/blahs/1") }.
        to raise_error Api::RemoteResource::GetFailed
    end

    it "shouldn't set the present flag to true if the JSON doesn't parse" do
      stub_request(:get, "http://example.com/v1/blahs/1").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean', 'X-Api-Token'=>'totally-fake-token'}).
         to_return(:status => 200, :body => "won't parse", :headers => {'Content-Type'=>'application/json'})
      rr = Api::RemoteResource.new("http://example.com/v1/blahs/1")
      expect { rr.get! }.to raise_error Api::RemoteResource::UnparseableJson
      expect(rr.present?).to eq false
    end
  end


  describe "_setup" do

    before :each do
      @rr = Api::RemoteResource.new("http://example.com/v1/blahs/1")
    end

    it "should set raw to any parsed JSON" do
      expect { @rr.send :_setup, [1,2,3], nil }.to raise_error Api::RemoteResource::JsonIsNoResource
      expect(@rr.raw).to eq [1,2,3]
    end

    it "should raise JsonIsNoResource if the JSON isn't a Hash" do
      expect { @rr.send(:_setup, [1,2,3], nil) }.to raise_error Api::RemoteResource::JsonIsNoResource
      expect { @rr.send(:_setup, true, nil) }.to raise_error Api::RemoteResource::JsonIsNoResource
      expect { @rr.send(:_setup, "hello", nil) }.to raise_error Api::RemoteResource::JsonIsNoResource
      expect { @rr.send(:_setup, nil, nil) }.to raise_error Api::RemoteResource::JsonIsNoResource
      expect { @rr.send(:_setup, 24, nil) }.to raise_error Api::RemoteResource::JsonIsNoResource
    end

    it "should raise JsonIsNoResource if the JSON hash doesn't have exactly one element" do
      expect { @rr.send(:_setup, {a: {}, b: {}}, nil) }.
        to raise_error Api::RemoteResource::JsonIsNoResource
    end

    it "should raise JsonIsNoResource if the value is not a Hash" do
      expect { @rr.send :_setup, {"blah"=>[]}, nil }.
        to raise_error Api::RemoteResource::JsonIsNoResource
    end

    it "should raise JsonIsNoResource if the value doesn't have a links hash" do
      expect { @rr.send :_setup, {"blah"=>{}}, nil }.
        to raise_error Api::RemoteResource::JsonIsNoResource
    end

    it "should raise JsonIsNoResource if the links hash doesn't have a self hash" do
      expect { @rr.send :_setup, {"blah"=>{"_links"=>{"self"=>17}}}, nil }.
        to raise_error Api::RemoteResource::JsonIsNoResource
    end

    it "should raise JsonIsNoResource if the self hash doesn't have a href string" do
      expect { @rr.send :_setup, {"blah"=>{"_links"=>{"self"=>{"href"=>nil}}}}, nil }.
        to raise_error Api::RemoteResource::JsonIsNoResource
    end

    it "should raise JsonIsNoResource if the self hash doesn't have a type string" do
      expect { @rr.send :_setup, {"blah"=>{"_links"=>{"self"=>{"href"=>"http://example.com/v1/blahs/1","type"=>123}}}}, nil }.
        to raise_error Api::RemoteResource::JsonIsNoResource
    end


    describe "given resource json" do

      before :each do
        @json = {"blah"=>{"_links"=>{"self"=>{"href"=>"http://example.com/v1/blahs/1","type"=>"application/json"}}}} 
        @rr.send :_setup, @json, double(status: 200, message: "OK", headers: {})
      end

      it "should set resource when successful" do
        expect(@rr.resource).to eq @json['blah']
      end

      it "should set resource_type when successful" do
        expect(@rr.resource_type).to eq "blah"
      end

      it "should set status when successful" do
        expect(@rr.status).to eq 200
      end

      it "should set headers when successful" do
        expect(@rr.headers).to eq({})
      end
    end
  end



  describe ".get!" do

    it "can take a /v1/foos type URI" do
      allow(Api).to receive(:service_token).and_return("so-fake")
      stub_request(:get, "#{INTERNAL_OCEAN_API_URL}/v1/foos").
         to_return(:status => 200, :body => "", :headers => {})
      Api::RemoteResource.get("/v1/foos")
    end

  end


  describe ".get" do

    it "returns a new RemoteResource" do
      allow(Api).to receive(:service_token).and_return("so-fake")
      expect(Api).to receive(:request).and_return(@successful)  
      expect(Api::RemoteResource.get "http://example.com/v1/blahs/1").to be_a Api::RemoteResource
    end

    it "returns a new RemoteResource even if there was an error" do
      allow(Api).to receive(:service_token).and_return("so-fake")
      expect(Api).to receive(:request).
        and_return(double(success?: false, status: 403, message: "Forbidden", headers: {}))      
      expect(Api::RemoteResource.get "http://example.com/v1/blahs/1").to be_a Api::RemoteResource
    end
  end

end


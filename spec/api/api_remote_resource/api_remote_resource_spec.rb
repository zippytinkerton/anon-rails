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
    @successful = double success?: true, headers: {"Content-Type"=>"application/json"}, 
                         body: @good_json,
                         status: 200,
                         message: "Success"
  end


  describe "instances should respond to" do

    accessors = [:uri, :args, :content_type, :retries, :backoff_time, :backoff_rate, :backoff_max,
                 :raw, :resource, :resource_type, :status, :headers, :credentials, :x_api_token,
                 :status_message, :response, :etag, :collection]

    accessors.each do |accessor|
      it "the accessor '#{accessor}'" do
        expect(Api::RemoteResource.new("foo")).to respond_to accessor
      end
    end
  end


  describe "keyword instance accessor" do

    describe "content_type" do
      it "should default to application/json" do
        expect(Api::RemoteResource.new("foo").content_type).to eq "application/json"
      end

      it "should be possible to supply at instantiation" do
        expect(Api::RemoteResource.new("foo", "image/jpeg").content_type).to eq "image/jpeg"
      end

      it "should not be settable" do
        expect { Api::RemoteResource.new("foo").content_type = "nope" }.to raise_error(NoMethodError)
      end
    end

    describe "retries" do
      it "should default to 3" do
        expect(Api::RemoteResource.new("foo").retries).to eq 3
      end

      it "should be possible to supply at instantiation" do
        expect(Api::RemoteResource.new("foo", retries: 0).retries).to eq 0
      end

      it "should not be settable" do
        expect { Api::RemoteResource.new("foo").retries = 8 }.to raise_error(NoMethodError)
      end
    end

    describe "backoff_time" do
      it "should default to 1" do
        expect(Api::RemoteResource.new("foo").backoff_time).to eq 1
      end

      it "should be possible to supply at instantiation" do
        expect(Api::RemoteResource.new("foo", backoff_time: 0.5).backoff_time).to eq 0.5
      end

      it "should not be settable" do
        expect { Api::RemoteResource.new("foo").backoff_time = 0.2 }.to raise_error(NoMethodError)
      end
    end

    describe "backoff_rate" do
      it "should default to 0.9" do
        expect(Api::RemoteResource.new("foo").backoff_rate).to eq 0.9
      end

      it "should be possible to supply at instantiation" do
        expect(Api::RemoteResource.new("foo", backoff_rate: 1.1).backoff_rate).to eq 1.1
      end

      it "should not be settable" do
        expect { Api::RemoteResource.new("foo").backoff_rate = 2.7 }.to raise_error(NoMethodError)
      end
    end

    describe "backoff_max" do
      it "should default to 30" do
        expect(Api::RemoteResource.new("foo").backoff_max).to eq 30
      end

      it "should be possible to supply at instantiation" do
        expect(Api::RemoteResource.new("foo", backoff_max: 10).backoff_max).to eq 10
      end

      it "should not be settable" do
        expect { Api::RemoteResource.new("foo").backoff_max = 5 }.to raise_error(NoMethodError)
      end
    end

    describe "credentials" do
      it "should default to nil" do
        expect(Api::RemoteResource.new("foo").credentials).to eq nil
      end

      it "should be possible to supply at instantiation" do
        expect(Api::RemoteResource.new("foo", credentials: "creds").credentials).to eq "creds"
      end

      it "should not be settable" do
        expect { Api::RemoteResource.new("foo").credentials = "nope" }.to raise_error(NoMethodError)
      end
    end

    describe "x_api_token" do
      it "should default to nil" do
        expect(Api::RemoteResource.new("foo").x_api_token).to eq nil
      end

      it "should be possible to supply at instantiation" do
        expect(Api::RemoteResource.new("foo", x_api_token: "custom-token").x_api_token).to eq "custom-token"
      end

      it "should not be settable" do
        expect { Api::RemoteResource.new("foo").x_api_token = "another-token" }.to raise_error(NoMethodError)
      end
    end
  end


  describe do

    before :each do
      @rr = Api::RemoteResource.new("http://example.com/v1/blahs/1")
      allow(Api).to receive(:service_token).and_return("so-fake")
      stub_request(:get, "http://example.com/v1/blahs/1").
        with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ocean', 'X-Api-Token'=>'so-fake'}).
        to_return(:status => 200, 
                  :body => @good_json.to_json, 
                  :headers => {'Content-Type' => 'application/json'})
    end


    describe "attributes" do

      it "should be readable" do
        expect(@rr["foo"]).to eq 123
      end

      it "should retrieve the resource if not present" do
        expect(@rr["foo"]).to eq 123
      end

      it "should not retrieve the resource if already present" do
        expect(@rr.present?).to eq false
        expect(@rr).to receive(:_retrieve).and_call_original
        expect(@rr["foo"]).to eq 123
        expect(@rr.present?).to eq true
        expect(Api::RemoteResource).not_to receive(:_retrieve)
        expect(@rr["foo"]).to eq 123
      end


      it "should be settable" do
        expect(@rr["bar"]).to eq [1,2,3]
        @rr["bar"] = "Hey ho"
        expect(@rr["bar"]).to eq "Hey ho"
      end
    end



    it "#hyperlink should return the hyperlink attribute" do
      expect(@rr.hyperlink).to eq({"self"=>{"href"=>"http://example.com/v1/blahs/1", 
                                            "type"=>"application/json"}, 
                                   "quux"=>{"href"=>"http://acme.com/v1/quux/1", 
                                            "type"=>"application/json"}})
    end

    it "#href should return the self hyperlink href" do
      expect(@rr.href).to eq "http://example.com/v1/blahs/1"
    end

    it "#type should return the self hyperlink type" do
      expect(@rr.type).to eq "application/json"
    end
  end

end


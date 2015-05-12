require 'spec_helper'

describe Api::RemoteResource, :type => :model do

  before :each do
    # This is for the basic resource
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
                         headers: {"Content-Type"=>"application/json", "ETag"=>"LALA"}, 
                         body: @good_json,
                         status: 200,
                         message: "Success"

    @rr = Api::RemoteResource.new("http://example.com/v1/blahs/1")
    allow(Api).to receive(:service_token).and_return("so-fake")
    allow(Api).to receive(:request).
      with("http://example.com/v1/blahs/1", :get, args: nil,
           :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
           :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
      and_return(@successful)

    # This is for the hyperlink 
    @quux = {"quux"=>{
                    "_links"=>{"self"=>{"href"=>"http://acme.com/v1/quux/1",
                                        "type"=>"application/json"}
                              },
                    "bip" => "lalala",
                    "bop" => true
                 }}
    @quux_success = double success?: true, headers: {"Content-Type"=>"application/json"}, 
                           body: @quux,
                           status: 200,
                           message: "Success"
    allow(Api).to receive(:request).
        with("http://acme.com/v1/quux/1", :get, args: nil,
             :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@quux_success)
  end




  describe "#get!" do

    it "only makes an HTTP request if the resource isn't already present" do
      @rr.get!
      expect(Api).not_to receive(:request)
      @rr.get!
    end

    it "should take an optional hyperlink argument" do
      @rr.get!(:self)
    end

    it "should allow the use of symbols or strings as hyperlinks" do
      expect(@rr.get!("self")).to eq @rr.get!(:self)
    end

    it "should raise an exception if the hyperlink can't be found" do
      expect { @rr.get!("blahonga") }.
        to raise_error Api::RemoteResource::HyperlinkMissing, "blah has no blahonga hyperlink"
    end

    it "should make another GET request to the indicated hyperlink, if present and not :self" do
      expect(@rr.get!(:quux)['bop']).to eq true
    end

    it "should treat #get!() and #get!(:self) identically, not making another GET request" do
      expect(@rr.get!(:self)).to eq @rr.get!
    end

    it "should raise an error if the GET failed" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :get, args: nil, :headers=>{},
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(double success?: false, status: 403, message: "Forbidden", headers: {})
      expect { @rr.get! }.to raise_error Api::RemoteResource::GetFailed, "403 Forbidden"
    end

    it "should set the etag if the GET was successful" do
      @rr.get!
      expect(@rr.etag).to eq "LALA"
    end

    it "shouldn't set the etag if there was an exception" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :get, args: nil, 
             :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_raise ZeroDivisionError      
      expect { @rr.get! }.to raise_error ZeroDivisionError
      expect(@rr.etag).to eq nil
    end

    it "shouldn't set the etag if the GET wasn't successful" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :get, args: nil, :headers=>{},
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(double success?: false, status: 403, message: "Forbidden", headers: {})
      expect { @rr.get! }.to raise_error Api::RemoteResource::GetFailed, "403 Forbidden"
      expect(@rr.etag).to eq nil
    end

    it "should accept an :args keyword and add it to the path" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :get, args: nil, 
             :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).ordered.
        and_return(@successful)        
      expect(Api).to receive(:request).
        with("http://acme.com/v1/quux/1", :get, args: {x: 1, 'y' => 'blah'},
             :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).ordered.
        and_return(@quux_success)
      Api::RemoteResource.new("http://example.com/v1/blahs/1").get!(:quux, args: {x: 1, 'y' => 'blah'})
    end

    it "should inherit retry settings when following an hyperlink" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :get, args: nil, 
             :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>2000, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).ordered.
        and_return(@successful)        
      expect(Api).to receive(:request).
        with("http://acme.com/v1/quux/1", :get, args: {x: 1, 'y' => 'blah'},
             :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>2000, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).ordered.
        and_return(@quux_success)
      Api::RemoteResource.new("http://example.com/v1/blahs/1", retries: 2000).get!(:quux, args: {x: 1, 'y' => 'blah'})
    end
  end


  describe "#get" do

    it "only makes an HTTP request if the resource isn't already present" do
      @rr.get
      expect(Api).not_to receive(:request)
      @rr.get
    end

    it "returns a new RemoteResource" do
      expect(@rr.get).to be_a Api::RemoteResource
    end

    it "returns a new RemoteResource even if there was an error" do
      expect(Api).to receive(:request).
        and_return(double(success?: false, status: 403, message: "Forbidden", headers: {}))      
      rr = Api::RemoteResource.new "http://example.com/v1/blahs/1"
      expect(rr.get).to be_a Api::RemoteResource
    end

    it "should follow hyperlinks, just like #get!" do
      expect(@rr.get(:quux)['bop']).to eq true
    end

    it "should accept an :args keyword and add it to the path" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :get, args: nil, 
             :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).ordered.
        and_return(@successful)        
      expect(Api).to receive(:request).
        with("http://acme.com/v1/quux/1", :get, args: {x: 1, 'y' => 'blah'},
             :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).ordered.
        and_return(@quux_success)
      Api::RemoteResource.new("http://example.com/v1/blahs/1").get(:quux, args: {x: 1, 'y' => 'blah'})
    end

    it "should inherit retry settings when following an hyperlink" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :get, args: nil, 
             :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>2000, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).ordered.
        and_return(@successful)        
      expect(Api).to receive(:request).
        with("http://acme.com/v1/quux/1", :get, args: {x: 1, 'y' => 'blah'},
             :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>2000, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).ordered.
        and_return(@quux_success)
      Api::RemoteResource.new("http://example.com/v1/blahs/1", retries: 2000).get(:quux, args: {x: 1, 'y' => 'blah'})
    end
  end
end


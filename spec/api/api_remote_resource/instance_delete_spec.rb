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
                         headers: {"Content-Type"=>"application/json", "ETag"=>"BAAB"}, 
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
    @quux_success = double success?: true, 
                           headers: {"Content-Type"=>"application/json", "ETag"=>"YMMV"}, 
                           body: @quux,
                           status: 200,
                           message: "Success"
    allow(Api).to receive(:request).
        with("http://acme.com/v1/quux/1", :get, 
             :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@quux_success)
  end




  describe "#delete!" do

    it "only makes an HTTP request if the resource isn't already present" do
      expect(@rr).to receive(:_retrieve).once.and_call_original
      expect(@rr).to receive(:_destroy).twice
      @rr.delete!
      @rr.delete!
    end

    it "should take an optional hyperlink argument" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :delete, args: nil, 
           :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
           :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@successful)
      @rr.delete!(:self)
    end

    it "should do a DELETE request on the proper URI" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :delete, args: nil, :headers=>{}, 
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@successful)
      @rr.delete!
      expect(@rr.etag).to eq "BAAB"
    end

    it "should raise an error if the DELETE failed" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :delete, args: nil, :headers=>{},
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(double success?: false, status: 502, message: "Bad Gateway", headers: {})
      expect { @rr.delete! }.to raise_error Api::RemoteResource::DeleteFailed, "502 Bad Gateway"
      expect(@rr.etag).to eq "BAAB"
    end

    it "should always set status, message and headers" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :delete, args: nil, :headers=>{},
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(double success?: false, status: 666, message: "The Beast", headers: {"x"=>2})
      expect { @rr.delete! }.to raise_error Api::RemoteResource::DeleteFailed, "666 The Beast"
      expect(@rr.status).to eq 666
      expect(@rr.status_message).to eq "The Beast"
      expect(@rr.headers).to eq("x"=>2)
    end

    it "should take an optional hyperlink argument" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :delete, args: nil, 
           :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
           :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@successful)
      @rr.delete!(:self)
    end

    it "should allow the use of symbols or strings as hyperlinks" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :delete, args: nil, 
           :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
           :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@successful)
      @rr.delete!("self")
    end

    it "should raise an exception if the hyperlink can't be found" do
      expect { @rr.delete!("blahonga") }.
        to raise_error Api::RemoteResource::HyperlinkMissing, "blah has no blahonga hyperlink"
    end

    it "should use a hyperlink, if given" do
      expect(Api).to receive(:request).
        with("http://acme.com/v1/quux/1", :delete, args: nil, 
           :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
           :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@successful)
      @rr.delete!(:quux)
    end

    it "returns the basic RemoteResource" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :delete, args: nil, 
           :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
           :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@successful)
      expect(@rr.delete).to eq @rr
    end

    it "should accept an :args keyword and add it to the path" do
      expect(Api).to receive(:request).
        with("http://acme.com/v1/quux/1", :delete, :args=>{x: 1, 'y' => 'blah'}, 
             :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@quux_success)
      Api::RemoteResource.new("http://example.com/v1/blahs/1").delete!(:quux, args: {x: 1, 'y' => 'blah'})
    end
  end


  describe "#delete" do

    it "only makes an HTTP request if the resource isn't already present" do
      expect(@rr).to receive(:_retrieve).once.and_call_original
      expect(@rr).to receive(:_destroy).twice
      @rr.delete
      @rr.delete
    end

    it "doesn't raise errors if the HTTP DELETE operation failed" do
      allow(@rr).to receive(:_destroy).and_raise StandardError
      expect { @rr.delete }.not_to raise_error
    end

    it "returns the basic RemoteResource" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :delete, args: nil,
           :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
           :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@successful)
      expect(@rr.delete).to eq @rr
    end

    it "returns the basic RemoteResource even if there was an error" do
      allow(@rr).to receive(:_destroy).and_raise StandardError
      expect(@rr.delete).to eq @rr
    end

    it "should follow hyperlinks, just like #delete!" do
      expect(Api).to receive(:request).
        with("http://acme.com/v1/quux/1", :delete, args: nil, 
             :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@quux_success)
      @rr.delete!(:quux)
    end

    it "returns the basic RemoteResource, even if a hyperlink was used" do
      expect(Api).to receive(:request).
        with("http://acme.com/v1/quux/1", :delete, args: nil, 
             :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@quux_success)
      expect(@rr.delete!(:quux)).to eq @rr
    end

    it "should accept an :args keyword and add it to the path" do
      expect(Api).to receive(:request).
        with("http://acme.com/v1/quux/1", :delete, :args=>{x: 1, 'y' => 'blah'}, 
             :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@quux_success)
      Api::RemoteResource.new("http://example.com/v1/blahs/1").delete(:quux, args: {x: 1, 'y' => 'blah'})
    end
  end
end


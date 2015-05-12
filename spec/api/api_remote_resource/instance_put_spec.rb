require 'spec_helper'

describe Api::RemoteResource, :type => :model do

  before :each do
    @rr = Api::RemoteResource.new("http://example.com/v1/blahs/1")
    allow(Api).to receive(:service_token).and_return("so-fake")
    # This is for the basic resource
    @good_json = {"blah"=>{
                    "_links"=>{"self"=>{"href"=>"http://example.com/v1/blahs/1",
                                        "type"=>"application/json"},
                               "quux"=>{"href"=>"http://acme.com/v1/quux/1",
                                        "type"=>"application/json"}},
                    "foo" => 123,
                    "bar" => [1,2,3]}}
    @successful = double success?: true, 
                         headers: {"Content-Type"=>"application/json", "ETag"=>"BAAB"}, 
                         body: @good_json,
                         status: 200,
                         message: "Success"

    expect(Api).to receive(:request).
      with("http://example.com/v1/blahs/1", :get, args: nil,
           :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
           :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
      and_return(@successful)

    # This is an updated resource, with a different foo value
    @updated_json = {"blah"=>{
                      "_links"=>{"self"=>{"href"=>"http://example.com/v1/blahs/1",
                                          "type"=>"application/json"},
                                 "quux"=>{"href"=>"http://acme.com/v1/quux/1",
                                          "type"=>"application/json"}},
                     "foo" => "updated",
                     "bar" => [1,2,3]}}
    @updated = double success?: true, 
                         headers: {"Content-Type"=>"application/json", "ETag"=>"ROFL"}, 
                         body: @updated_json,
                         status: 200,
                         message: "Success"

    # This is for the updated main resource
    allow(Api).to receive(:request).
      with("http://example.com/v1/blahs/1", :put, :args=>nil, 
           :headers=>{}, body: "{}",
           :credentials=>nil, :x_api_token=>"so-fake", 
           :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
      and_return(@updated)

    # This is for the updated hyperlink 
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
  end




  describe "#put!" do

    it "always makes a PUT HTTP request, but only makes an initial GET request if the resource isn't already present" do
      expect(@rr).to receive(:_retrieve).once.and_call_original
      expect(@rr).to receive(:_modify).twice
      @rr.put!
      @rr.put!
    end

    it "allows the body to be set using the :body keyword" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :put, :args=>nil, :headers=>{}, body: '{"be":"bop"}',
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@updated)
      @rr.put!(body: {"be" => "bop"})
    end

    it "defaults :body to {}" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :put, :args=>nil, :headers=>{}, body: "{}",
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@updated)
      @rr.put!
    end

    it "should convert the body to JSON" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :put, :args=>nil, :headers=>{}, body: '{"be":"bop"}',
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@updated)
      @rr.put!(body: {"be" => "bop"})
    end

    it "updates the resource if a valid resource body of matching type is returned" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :put, :args=>nil, :headers=>{}, body: "{}",
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@updated)
      @rr.put!
      expect(@rr['foo']).to eq "updated"
      expect(@rr.present?).to eq true
    end

    it "updates the etag if a valid resource body of matching type is returned" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :put, :args=>nil, :headers=>{}, body: "{}",
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@updated)
      @rr.put!
      expect(@rr['foo']).to eq "updated"
      expect(@rr.present?).to eq true
      expect(@rr.etag).to eq "ROFL"
    end

    it "should raise PutError and not update the local resource if the PUT failed" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :put, :args=>nil, :headers=>{}, body: "{}",
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(double success?: false, status: 404, message: "Not found", :headers=>{})
      expect { @rr.put! }.to raise_error Api::RemoteResource::PutFailed, "404 Not found"
      expect(@rr['foo']).to eq 123
      expect(@rr.etag).to eq "BAAB"
    end

    it "does quietly not update the local resource if the response body isn't a valid resource" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :put, :args=>nil, :headers=>{}, body: "{}",
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(double success?: true, status: 200, message: "OK", :headers=>{}, 
                          body: {})
      @rr.put!
      expect(@rr['foo']).to eq 123
      expect(@rr.etag).to eq "BAAB"
    end

    it "does quietly not update the local resource if the resource type is different" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :put, :args=>nil, :headers=>{}, body: "{}",
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(double success?: true, status: 200, message: "OK", :headers=>{}, 
                          body: { "moo" => @updated_json['blah']})
      @rr.put!
      expect(@rr['foo']).to eq 123
      expect(@rr.etag).to eq "BAAB"
    end

    it "should take an optional hyperlink argument" do
      @rr.put!(:self)
    end

    it "should allow the use of symbols or strings as hyperlinks" do
      expect(@rr.put!("self")).to eq @rr.put!(:self)
    end

    it "should raise an exception if the hyperlink can't be found" do
      expect { @rr.put!("blahonga") }.
        to raise_error Api::RemoteResource::HyperlinkMissing, "blah has no blahonga hyperlink"
    end

    it "should return the new RemoteResource when a hyperlink is specified for PUT" do
      expect(Api).to receive(:request).
        with("http://acme.com/v1/quux/1", :put, :args=>nil, 
             :headers=>{}, body: "{}",
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@quux_success)
      quux = @rr.put!(:quux)
      expect(quux).to be_a Api::RemoteResource
      expect(quux).not_to eq @rr
      expect(quux.present?).to eq true
      expect(quux.href).to eq "http://acme.com/v1/quux/1"
    end

    it "should treat #put!() and #put!(:self) identically" do
      expect(@rr.put!(:self)).to eq @rr.put!
    end

    it "should accept an :args keyword and add it to the path" do
      expect(Api).to receive(:request).
        with("http://acme.com/v1/quux/1", :put, :args=>{x: 1, 'y' => 'blah'}, 
             :headers=>{}, body: "{}", :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@quux_success)
      Api::RemoteResource.new("http://example.com/v1/blahs/1").put!(:quux, args: {x: 1, 'y' => 'blah'})
    end
  end


  describe "#put" do

    it "always makes a PUT HTTP request, but only makes an initial GET request if the resource isn't already present" do
      expect(@rr).to receive(:_retrieve).once.and_call_original
      expect(@rr).to receive(:_modify).twice
      @rr.put
      @rr.put
    end

    it "doesn't raise errors if the HTTP PUT operation failed" do
      allow(@rr).to receive(:_modify).and_raise StandardError
      expect { @rr.put }.not_to raise_error
    end

    it "returns a RemoteResource" do
      expect(@rr.put).to be_a Api::RemoteResource
    end

    it "returns a RemoteResource even if there was an error" do
      expect(Api).to receive(:request).
        and_return(double(success?: false, status: 403, message: "Forbidden", headers: {}))      
      rr = Api::RemoteResource.new "http://example.com/v1/blahs/1"
      expect(rr.put).to be_a Api::RemoteResource
    end

    it "should follow hyperlinks, just like #put!" do
      expect(Api).to receive(:request).
        with("http://acme.com/v1/quux/1", :put, :args=>nil, 
             :headers=>{}, body: "{}",
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@quux_success)
      quux = @rr.put!(:quux)
      expect(quux).to be_a Api::RemoteResource
      expect(quux).not_to eq @rr
      expect(quux.present?).to eq true
      expect(quux.href).to eq "http://acme.com/v1/quux/1"
    end

    it "should accept an :args keyword and add it to the path" do
      expect(Api).to receive(:request).
        with("http://acme.com/v1/quux/1", :put, :args=>{x: 1, 'y' => 'blah'}, 
             :headers=>{}, body: "{}", :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@quux_success)
      Api::RemoteResource.new("http://example.com/v1/blahs/1").put(:quux, args: {x: 1, 'y' => 'blah'})
    end
  end
end


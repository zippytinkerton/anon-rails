require 'spec_helper'

describe Api::RemoteResource, :type => :model do

  before :each do
    @rr = Api::RemoteResource.new("http://example.com/v1/blahs/1")
    allow(Api).to receive(:service_token).and_return("so-fake")
    # This is for the basic resource
    @good_json = {"blah"=>{
                    "_links"=>{"self"=>{"href"=>"http://example.com/v1/blahs/1",
                                        "type"=>"application/json"},
                               "quuxes"=>{"href"=>"http://acme.com/v1/quuxes",
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

    # This is a new Quux
    @new_json = {"quux"=>{
                      "_links"=>{"self"=>{"href"=>"http://acme.com/v1/quuxes/123",
                                            "type"=>"application/json"},
                                 "blah"=>{"href"=>"http://example.com/v1/blahs/1",
                                          "type"=>"application/json"}},
                     "foo" => "new resource",
                     "bar" => [1,2,3]}}
    @new_quux = double success?: true, 
                       headers: {"Content-Type"=>"application/json", "ETag"=>"ROFL"}, 
                       body: @new_json,
                       status: 200,
                       message: "Success"
  end



  describe "#post!" do

    it "always makes a PUT HTTP request, but only makes an initial GET request if the resource isn't already present" do
      expect(@rr).to receive(:_retrieve).once.and_call_original
      expect(@rr).to receive(:_create).twice
      @rr.post!
      @rr.post!
    end

    it "should raise an exception if the hyperlink can't be found" do
      expect { @rr.post!("blahonga") }.
        to raise_error Api::RemoteResource::HyperlinkMissing, "blah has no blahonga hyperlink"
    end

    it "allows the body to be set using the :body keyword" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :post, :args=>nil, :headers=>{}, body: '{"be":"bop"}',
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@new_quux)
      @rr.post!(body: {"be" => "bop"})
    end

    it "defaults :body to {}" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :post, :args=>nil, :headers=>{}, body: "{}",
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@new_quux)
      @rr.post!
    end

    it "should convert the body to JSON" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :post, :args=>nil, :headers=>{}, body: '{"be":"bop"}',
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@new_quux)
      @rr.post!(body: {"be" => "bop"})
    end

    it "should raise PostError if the POST failed" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :post, :args=>nil, :headers=>{}, body: "{}",
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(double success?: false, status: 404, message: "Not found", headers: {})
      expect { @rr.post! }.to raise_error Api::RemoteResource::PostFailed, "404 Not found"
      expect(@rr.etag).to eq "BAAB"
    end

    it "should raise JsonIsNoResource if the response body isn't a valid resource" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :post, :args=>nil, :headers=>{}, body: "{}",
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(double success?: true, status: 200, message: "OK", body: {}, headers: {})
      expect { @rr.post! }.to raise_error Api::RemoteResource::JsonIsNoResource
      expect(@rr.etag).to eq "BAAB"
    end

    it "creates a new Quux RemoteResource and returns it" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :post, :args=>nil, :headers=>{}, body: "{}",
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@new_quux)
      quux = @rr.post!
      expect(quux).to be_an Api::RemoteResource
      expect(quux).not_to eq @rr
      expect(quux.resource_type).to eq "quux"
      expect(quux.href).to eq "http://acme.com/v1/quuxes/123"
      expect(quux.present?).to eq true
      expect(quux.etag).to eq nil
    end

    it "should take an optional hyperlink argument" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :post, :args=>nil, :headers=>{}, body: "{}",
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@new_quux)
      @rr.post!(:self)
    end

    it "should use the hyperlink href" do
      expect(Api).to receive(:request).
        with("http://acme.com/v1/quuxes", :post, :args=>nil, :headers=>{}, body: "{}",
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@new_quux)
      quux = @rr.post!(:quuxes)
      expect(quux).to be_an Api::RemoteResource
      expect(quux).not_to eq @rr
      expect(quux.resource_type).to eq "quux"
      expect(quux.href).to eq "http://acme.com/v1/quuxes/123"
      expect(quux.present?).to eq true
    end

    it "should accept an :args keyword and add it to the path" do
      expect(Api).to receive(:request).
        with("http://acme.com/v1/quuxes", :post, :args=>{x: 1, 'y' => 'blah'}, 
             :headers=>{}, body: "{}", :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@new_quux)
      Api::RemoteResource.new("http://example.com/v1/blahs/1").post!(:quuxes, args: {x: 1, 'y' => 'blah'})
    end
  end


  describe "#post" do

    it "always makes a PUT HTTP request, but only makes an initial GET request if the resource isn't already present" do
      expect(@rr).to receive(:_retrieve).once.and_call_original
      expect(@rr).to receive(:_create).twice
      @rr.post
      @rr.post
    end

    it "returns nil if the HTTP PUT operation failed" do
      allow(@rr).to receive(:_create).and_raise StandardError
      expect(@rr.post).to eq nil
    end

    it "returns a new RemoteResource if successful" do
      expect(Api).to receive(:request).
        with("http://example.com/v1/blahs/1", :post, :args=>nil, :headers=>{}, body: "{}",
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@new_quux)
      quux = @rr.post
      expect(quux).to be_an Api::RemoteResource
      expect(quux).not_to eq @rr
      expect(quux.resource_type).to eq "quux"
      expect(quux.href).to eq "http://acme.com/v1/quuxes/123"
      expect(quux.present?).to eq true
    end

    it "should follow hyperlinks, just like #post!" do
      expect(Api).to receive(:request).
        with("http://acme.com/v1/quuxes", :post, :args=>nil, :headers=>{}, body: "{}",
             :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@new_quux)
      quux = @rr.post(:quuxes)
      expect(quux).to be_an Api::RemoteResource
      expect(quux).not_to eq @rr
      expect(quux.resource_type).to eq "quux"
      expect(quux.href).to eq "http://acme.com/v1/quuxes/123"
      expect(quux.present?).to eq true
    end

    it "should accept an :args keyword and add it to the path" do
      expect(Api).to receive(:request).
        with("http://acme.com/v1/quuxes", :post, :args=>{x: 1, 'y' => 'blah'}, 
             :headers=>{}, body: "{}", :credentials=>nil, :x_api_token=>"so-fake", 
             :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
        and_return(@new_quux)
      Api::RemoteResource.new("http://example.com/v1/blahs/1").post(:quuxes, args: {x: 1, 'y' => 'blah'})
    end
  end
end


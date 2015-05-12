require 'spec_helper'

describe Api::RemoteResource, :type => :model do

  before :each do
    # This is for the basic resource
    @item = {"blah"=>{
                    "_links"=>{"self"=>{"href"=>"http://example.com/v1/blahs/1",
                                        "type"=>"application/json"},
                               "quux"=>{"href"=>"http://acme.com/v1/quux/1",
                                        "type"=>"application/json"}
                              },
                    "foo" => 123,
                    "bar" => [1,2,3]
                 }}
    @collection = {
      "_collection" => {
        "resources" => [@item, @item, @item],
        "count" => 3
      }
    }
    @successful = double success?: true, 
                         headers: {"Content-Type"=>"application/json", "ETag"=>"TRALALA"}, 
                         body: @collection,
                         status: 200,
                         message: "Success"

    @rr = Api::RemoteResource.new("http://example.com/v1/blahs")
    allow(Api).to receive(:service_token).and_return("so-fake")
    allow(Api).to receive(:request).
      with("http://example.com/v1/blahs", :get, args: nil,
           :headers=>{}, :credentials=>nil, :x_api_token=>"so-fake", 
           :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
      and_return(@successful)
  end



  describe ".get!, when receiving a collection" do

    it "should not raise an error" do
      expect { Api::RemoteResource.get!("http://example.com/v1/blahs") }.
        not_to raise_error
    end

    it "should set #resource to nil and #collection to the collection array" do
      rr = Api::RemoteResource.get!("http://example.com/v1/blahs")
      expect(rr.resource).to eq nil
      expect(rr.collection).to be_an Array
      expect(rr.collection.length).to eq 3
    end

    it "should turn each collection item into a RemoteResource" do
      rr = Api::RemoteResource.get!("http://example.com/v1/blahs")
      rr.collection.each { |r| expect(r).to be_an Api::RemoteResource }
    end

    it "should return RemoteResources which are #present?" do
      rr = Api::RemoteResource.get!("http://example.com/v1/blahs")
      rr.collection.each { |r| expect(r.present?).to eq true }
    end

  end


  describe ".get, when receiving a collection" do

    it "should not raise an error" do
      expect { Api::RemoteResource.get("http://example.com/v1/blahs") }.
        not_to raise_error
    end

    it "should set #resource to nil and #collection to the collection array" do
      rr = Api::RemoteResource.get("http://example.com/v1/blahs")
      expect(rr.resource).to eq nil
      expect(rr.collection).to be_an Array
      expect(rr.collection.length).to eq 3
    end

    it "should turn each collection item into a RemoteResource" do
      rr = Api::RemoteResource.get("http://example.com/v1/blahs")
      rr.collection.each { |r| expect(r).to be_an Api::RemoteResource }
    end

    it "should return RemoteResources which are #present?" do
      rr = Api::RemoteResource.get("http://example.com/v1/blahs")
      rr.collection.each { |r| expect(r.present?).to eq true }
    end

  end


  describe "#get!" do

    it "should not raise an error" do
      expect { @rr.get! }.not_to raise_error
    end

    it "should set #resource to nil and #collection to the collection array" do
      @rr.get!
      expect(@rr.resource).to eq nil
      expect(@rr.collection).to be_an Array
      expect(@rr.collection.length).to eq 3
    end

    it "should turn each collection item into a RemoteResource" do
      @rr.get!
      @rr.collection.each { |r| expect(r).to be_an Api::RemoteResource }
    end

    it "should return RemoteResources which are #present?" do
      @rr.get!
      @rr.collection.each { |r| expect(r.present?).to eq true }
    end

  end


  describe "#get" do

    it "should not raise an error" do
      expect { @rr.get }.not_to raise_error
    end

    it "should set #resource to nil and #collection to the collection array" do
      @rr.get
      expect(@rr.resource).to eq nil
      expect(@rr.collection).to be_an Array
      expect(@rr.collection.length).to eq 3
    end
    
    it "should turn each collection item into a RemoteResource" do
      @rr.get
      @rr.collection.each { |r| expect(r).to be_an Api::RemoteResource }
    end

    it "should return RemoteResources which are #present?" do
      @rr.get
      @rr.collection.each { |r| expect(r.present?).to eq true }
    end

  end



end

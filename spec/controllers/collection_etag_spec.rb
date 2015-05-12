require 'spec_helper'

describe TheModelsController, :type => :controller do
  
  describe "collection_etag" do
    
    before :each do
      permit_with 200
      allow(Api).to receive(:ban)
      @m1 = create :the_model, updated_at: "2030-01-01", lock_version: 10
      @m2 = create :the_model, updated_at: "2030-01-15", lock_version: 20
      @m3 = create :the_model, updated_at: "2030-10-01", lock_version: 30
      request.headers['HTTP_ACCEPT'] = "application/json"
      request.headers['X-API-Token'] = "boy-is-this-fake"
    end

    it "should respond" do
      expect(controller).to respond_to :collection_etag
    end

    it "should be able to take a class constant, meaning all instances of the class" do
      expect(controller.collection_etag(TheModel)).to eq({etag: "TheModel:3:#{@m3.updated_at}"})
    end

    it "should be able to take a class with no instances" do
      TheModel.destroy_all
      expect(controller.collection_etag(TheModel)).to eq({etag: "TheModel:0:0"})
    end

    it "should handle a scope" do
      the_scope = TheModel.where("lock_version < 25")
      expect(controller.collection_etag(the_scope)).to eq(etag: "TheModel:2:#{@m2.updated_at}")
    end

    it "should handle an empty array" do
      expect(controller.collection_etag([])).to eq(etag: "_unknown_:0:0")
    end

    it "should handle non-empty arrays by using the class of the first element" do
      expect(controller.collection_etag([@m3, @m2])).to eq({etag: "TheModel:2:#{@m3.updated_at}"})
    end
  end

end

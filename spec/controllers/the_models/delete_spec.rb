require 'spec_helper'

describe TheModelsController, :type => :controller do
  
  render_views

  describe "DELETE" do
    
    before :each do
      permit_with 200
      allow(Api).to receive(:ban)
      @the_model = create :the_model
      request.headers['HTTP_ACCEPT'] = "application/json"
      request.headers['X-API-Token'] = "so-totally-fake"
    end

    
    it "should return JSON" do
      delete :destroy, id: @the_model
      expect(response.content_type).to eq "application/json"
    end

    it "should return a 400 if the X-API-Token header is missing" do
      request.headers['X-API-Token'] = nil
      delete :destroy, id: @the_model
      expect(response.status).to eq 400
    end
    
    it "should return a 204 when successful" do
      delete :destroy, id: @the_model
      expect(response.status).to eq 204
      expect(response.content_type).to eq "application/json"
    end

    it "should return a 404 when the TheModel can't be found" do
      delete :destroy, id: -1
      expect(response.status).to eq 404
    end
    
    it "should destroy the TheModel when successful" do
      delete :destroy, id: @the_model
      expect(response.status).to eq 204
      expect(TheModel.find_by_id(@the_model.id)).to be_nil
    end
    
  end
  
end

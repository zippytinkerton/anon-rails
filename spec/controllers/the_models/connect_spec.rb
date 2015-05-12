require 'spec_helper'

describe TheModelsController, :type => :controller do
  
  render_views

  describe "PUT connect" do
    
    before :each do
      permit_with 200
      request.headers['HTTP_ACCEPT'] = "application/json"
      request.headers['X-API-Token'] = "incredibly-fake!"
      allow(Api).to receive(:ban)
      @u = create :the_model
    end


    it "should return JSON" do
      put :connect, id: @u.id
      expect(response.content_type).to eq "application/json"
    end
    
    it "should return a 400 if the X-API-Token header is missing" do
      request.headers['X-API-Token'] = nil
      put :connect, id: @u.id
      expect(response.status).to eq 400
    end

    it "should return a 404 if the resource can't be found" do
      put :connect, id: -1
      expect(response.status).to eq 404
      expect(response.content_type).to eq "application/json"
    end

    it "should return a 422 if the href query arg is missing" do
      put :connect, id: @u.id
      expect(response.status).to eq 422
      expect(response.body).to eq '{"_api_error":["href query arg is missing"]}'
    end

    it "should return a 422 if the href query arg isn't parseable" do
      put :connect, id: @u.id, href: "mnxyzptlk"
      expect(response.status).to eq 422
      expect(response.body).to eq '{"_api_error":["href query arg isn\'t parseable"]}'
    end

    it "should return a 404 if the href query arg resource can't be found" do
      put :connect, {id: @u.id, href: the_model_url(666)}
      expect(response.status).to eq 404
      expect(response.body).to eq '{"_api_error":["Resource to connect not found"]}'
    end

    it "should return a 204 and set @connectee and @connectee_class when successful" do
      other = create :the_model
      put :connect, {id: @u.id, href: the_model_url(other)}
      expect(response.status).to eq 204
      expect(assigns(:connectee)).to eq other
      expect(assigns(:connectee_class)).to eq TheModel
    end
        
  end
  
end

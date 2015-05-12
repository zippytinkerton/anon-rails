require 'spec_helper'

describe TheModelsController, :type => :controller do
  
  render_views

  describe "PUT" do
    
    before :each do
      permit_with 200
      request.headers['HTTP_ACCEPT'] = "application/json"
      request.headers['X-API-Token'] = "incredibly-fake!"
      allow(Api).to receive(:ban)
      @u = create :the_model
      @args = @u.attributes
    end


    it "should return JSON" do
      put :update, @args
      expect(response.content_type).to eq "application/json"
    end
    
    it "should return a 400 if the X-API-Token header is missing" do
      request.headers['X-API-Token'] = nil
      put :update, @args
      expect(response.status).to eq 400
    end

    it "should return a 404 if the resource can't be found" do
      put :update, @args.merge(id: -1)
      expect(response.status).to eq 404
      expect(response.content_type).to eq "application/json"
    end

    it "should return a 422 when resource properties are missing (all must be set simultaneously)" do
      put :update, id: @u.id
      expect(response.status).to eq 422
      expect(response.content_type).to eq "application/json"
    end

    it "should return a 409 when there is an update conflict" do
      @u.update_attributes!({updated_at: 1.week.from_now}, :without_protection => true)
      put :update, @args
      expect(response.status).to eq 409
    end
        
    it "should return a 200 when successful" do
      put :update, @args
      expect(response.status).to eq 200
      expect(response).to render_template(partial: "_the_model", count: 1)
    end

    it "should return the updated resource in the body when successful" do
      put :update, @args
      expect(response.status).to eq 200
      expect(JSON.parse(response.body)).to be_a Hash
    end

    it "should return a 422 when there are validation errors" do
      put :update, @args.merge('name' => "qz")
      expect(response.status).to eq 422
      expect(response.content_type).to eq "application/json"
      expect(JSON.parse(response.body)).to eq({"name"=>["is too short (minimum is 3 characters)"]})
    end


    it "should alter the user when successful" do
      expect(@u.name).to eq @args['name']
      expect(@u.description).to eq @args['description']
      @args['name'] = "zalagadoola"
      @args['description'] = "menchikaboola"
      put :update, @args
      expect(response.status).to eq 200
      @u.reload
      expect(@u.name).to eq "zalagadoola"
      expect(@u.description).to eq "menchikaboola"
    end

  end
  
end

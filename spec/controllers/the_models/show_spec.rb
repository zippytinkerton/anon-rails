require 'spec_helper'

describe TheModelsController, :type => :controller do
  
  render_views


  describe "Unauthorised GET" do

    it "should pass on any _api_errors received from the authorisation call" do
      deny_with 403, "Foo", "Bar", "Baz"
      allow(Api).to receive(:ban)
      @the_model = create :the_model
      request.headers['HTTP_ACCEPT'] = "application/json"
      request.headers['X-API-Token'] = "totally-fake"
      get :show, id: @the_model
      expect(response.status).to eq 403
      expect(response.content_type).to eq "application/json"
      expect(response.body).to eq '{"_api_error":["Foo","Bar","Baz"]}'
    end

  end


  describe "GET" do
    
    before :each do
      permit_with 200, group_names: ["Foo", "Bar"]
      allow(Api).to receive(:ban)
      @the_model = create :the_model, vip: "Klytaimnestra"
      request.headers['HTTP_ACCEPT'] = "application/json"
      request.headers['X-API-Token'] = "totally-fake"
      request.headers['If-None-Match'] = "some-etag-data-received-earlier"
    end


    it "should return JSON" do
      get :show, id: @the_model
      expect(response.content_type).to eq "application/json"
    end
    
    it "should return a 400 if the X-API-Token header is missing" do
      request.headers['X-API-Token'] = nil
      get :show, id: @the_model
      expect(response.status).to eq 400
      expect(response.content_type).to eq "application/json"
    end
    
    it "should return a 404 when the user can't be found" do
      get :show, id: -1
      expect(response.status).to eq 404
      expect(response.content_type).to eq "application/json"
    end

    it "should return a 200 when successful" do
      get :show, id: @the_model
      expect(response.status).to eq 200
      expect(response).to render_template(partial: "_the_model", count: 1)
    end

    it "should not include the vip attribute when successful if not Superuser" do
      get :show, id: @the_model
      expect(response.status).to eq 200
      expect(response).to render_template(partial: "_the_model", count: 1)
      expect(JSON.parse(response.body)['the_model']['vip']).to eq nil
    end
  end
  

  describe "GET with app/context" do
    
    before :each do
      permit_with 200, right: [{"app" => "foo", "context" => "bar"}]
      allow(Api).to receive(:ban)
      @the_model = create :the_model
      request.headers['HTTP_ACCEPT'] = "application/json"
      request.headers['X-API-Token'] = "totally-fake"
      request.headers['If-None-Match'] = "some-etag-data-received-earlier"
    end


    it "should return a 404 when the record doesn't match the app or context" do
      get :show, id: @the_model
      expect(response.status).to eq 404
      expect(response.content_type).to eq "application/json"
    end
  end


  describe "GET with Superuser status" do
    
    before :each do
      permit_with 200, group_names: ["Foo", "Superusers", "Bar"]
      allow(Api).to receive(:ban)
      @the_model = create :the_model, vip: "Klytaimnestra"
      request.headers['HTTP_ACCEPT'] = "application/json"
      request.headers['X-API-Token'] = "totally-fake"
      request.headers['If-None-Match'] = "some-etag-data-received-earlier"
    end


    it "should return a 404 when the record doesn't match the app or context" do
      get :show, id: @the_model
      expect(response.status).to eq 200
      expect(response.content_type).to eq "application/json"
      expect(JSON.parse(response.body)['the_model']['vip']).to eq "Klytaimnestra"
    end
  end
end

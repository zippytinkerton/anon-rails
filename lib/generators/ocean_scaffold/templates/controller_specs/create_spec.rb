require 'spec_helper'

describe <%= class_name.pluralize %>Controller do
  
  render_views
  
  describe "POST" do
    
    before :each do
      permit_with 200
      request.headers['HTTP_ACCEPT'] = "application/json"
      request.headers['X-API-Token'] = "incredibly-fake!"
      @args = build(:<%= singular_name %>).attributes
    end
    
    
    it "should return JSON" do
      post :create, @args
      response.content_type.should == "application/json"
    end
    
    it "should return a 400 if the X-API-Token header is missing" do
      request.headers['X-API-Token'] = nil
      post :create, @args
      response.status.should == 400
    end
    
    it "should return a 201 when successful" do
      post :create, @args
      response.should render_template(partial: "_<%= singular_name %>", count: 1)
      response.status.should == 201
    end

    it "should contain a Location header when successful" do
      post :create, @args
      response.headers['Location'].should be_a String
    end

    it "should return the new resource in the body when successful" do
      post :create, @args
      response.body.should be_a String
    end
    
    #
    # Uncomment this test as soon as there is one or more DB attributes that define
    # the uniqueness of a record.
    #
    # it "should return a 422 if the <%= singular_name %> already exists" do
    #   post :create, @args
    #   response.status.should == 201
    #   response.content_type.should == "application/json"
    #   post :create, @args
    #   response.status.should == 422
    #   response.content_type.should == "application/json"
    #   JSON.parse(response.body).should == {"_api_error" => ["<%= class_name %> already exists"]}
    # end

    #
    # Uncomment this test as soon as there is one or more DB attributes that need
    # validating.
    #
    # it "should return a 422 when there are validation errors" do
    #   post :create, @args.merge('name' => "qz")
    #   response.status.should == 422
    #   response.content_type.should == "application/json"
    #   JSON.parse(response.body).should == {"name"=>["is too short (minimum is 3 characters)"]}
    # end
                
  end
  
end

require 'spec_helper'

describe <%= class_name.pluralize %>Controller do
  
  render_views

  describe "DELETE" do
    
    before :each do
      permit_with 200
      @<%= singular_name %> = create :<%= singular_name %>
      request.headers['HTTP_ACCEPT'] = "application/json"
      request.headers['X-API-Token'] = "so-totally-fake"
    end

    
    it "should return JSON" do
      delete :destroy, id: @<%= singular_name %>
      response.content_type.should == "application/json"
    end

    it "should return a 400 if the X-API-Token header is missing" do
      request.headers['X-API-Token'] = nil
      delete :destroy, id: @<%= singular_name %>
      response.status.should == 400
    end
    
    it "should return a 204 when successful" do
      delete :destroy, id: @<%= singular_name %>
      response.status.should == 204
      response.content_type.should == "application/json"
    end

    it "should return a 404 when the <%= class_name %> can't be found" do
      delete :destroy, id: -1
      response.status.should == 404
    end
    
    it "should destroy the <%= class_name %> when successful" do
      delete :destroy, id: @<%= singular_name %>
      response.status.should == 204
      <%= class_name %>.find_by_id(@<%= singular_name %>.id).should be_nil
    end
    
  end
  
end

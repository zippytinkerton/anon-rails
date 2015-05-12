require "spec_helper"

describe TheModelsController, :type => :routing do
  describe "routing" do

    it "routes to #index" do
      expect(get("/v1/the_models")).to route_to("the_models#index")
    end

    it "routes to #show" do
      expect(get("/v1/the_models/1")).to route_to("the_models#show", :id => "1")
    end

    it "routes to #create" do
      expect(post("/v1/the_models")).to route_to("the_models#create")
    end

    it "routes to #update" do
      expect(put("/v1/the_models/1")).to route_to("the_models#update", :id => "1")
    end

    it "routes to #destroy" do
      expect(delete("/v1/the_models/1")).to route_to("the_models#destroy", :id => "1")
    end
    
    it "routes to #connect" do
      expect(put("/v1/the_models/1/connect")).to route_to("the_models#connect", :id => "1")
    end

    it "routes to #call_others" do
      expect(get("/v1/the_models/call_others")).to route_to("the_models#call_others")
    end

  end
end

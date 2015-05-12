require "spec_helper"

describe <%= class_name.pluralize %>Controller do
  describe "routing" do

    it "routes to #index" do
      get("/v1/<%= plural_name %>").should route_to("<%= plural_name %>#index")
    end

    it "routes to #show" do
      get("/v1/<%= plural_name %>/1").should route_to("<%= plural_name %>#show", id: "1")
    end

    it "routes to #create" do
      post("/v1/<%= plural_name %>").should route_to("<%= plural_name %>#create")
    end

    it "routes to #update" do
      put("/v1/<%= plural_name %>/1").should route_to("<%= plural_name %>#update", id: "1")
    end

    it "routes to #destroy" do
      delete("/v1/<%= plural_name %>/1").should route_to("<%= plural_name %>#destroy", id: "1")
    end

  end
end

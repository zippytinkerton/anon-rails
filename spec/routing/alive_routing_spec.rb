require "spec_helper"

describe AliveController, :type => :routing do
  describe "routing" do

    it "routes to #index" do
      expect(get("/alive")).to route_to("alive#index")
    end

  end
end

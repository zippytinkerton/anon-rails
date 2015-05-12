require 'spec_helper'

describe ApplicationHelper, :type => :helper do

  describe "hyperlinks" do

    it "should return an empty hash given no args" do
  	  expect(hyperlinks()).to eq({})
    end

    it "should return as many output array elements as input hash args" do
      expect(hyperlinks(self: "http://foo", 
      	         quux: "https://blah").count).to eq 2
    end

    it "should return a two-element hash for each arg" do
      expect(hyperlinks(self: "https://example.com/v1/blah")['self'].count).to eq 2
    end

    it "should return a href value for the value of each arg" do
      expect(hyperlinks(self: "blah")['self']['href']).to eq "blah"
    end

    it "should default the type to application/json for terse hyperlinks" do
      expect(hyperlinks(self: "blah")['self']['type']).to eq "application/json"
    end

    it "should accept non-terse values giving the href and type in a sub-hash" do
      hl = hyperlinks(self: {href: "https://xux", type: "image/jpeg"})
      expect(hl['self']['href']).to eq "https://xux"
      expect(hl['self']['type']).to eq "image/jpeg"
    end

  end


  describe "api_user_url" do

  	it "should accept exactly one argument" do
      expect { api_user_url() }.to raise_error
      expect { api_user_url(1, 2) }.to raise_error
  	end

    it "should build an ApiUser URI when given an integer" do
      expect(api_user_url(123)).to eq "https://forbidden.example.com/v1/api_users/123"
    end

  	it "should accept a non-true argument and default the user ID to zero" do
      expect(api_user_url(nil)).to   eq "https://forbidden.example.com/v1/api_users/0"
      expect(api_user_url(false)).to eq "https://forbidden.example.com/v1/api_users/0"
  	end

    it "should accept a blank string and default the user ID to zero" do
      expect(api_user_url("")).to  eq "https://forbidden.example.com/v1/api_users/0"
      expect(api_user_url(" ")).to eq "https://forbidden.example.com/v1/api_users/0"
    end

    it "should return a non-empty string directly" do
      expect(api_user_url("tjohoo")).to eq "tjohoo"
    end

    it "should raise an error if not given an integer, string, or nil" do
      expect { api_user_url(:wrong) }.to raise_error
    end


  end

end

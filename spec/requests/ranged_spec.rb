require 'spec_helper'

describe "ranged matches for TheModel collections", :type => :request do

  before :each do
    stub_const("LOAD_BALANCERS", [])
    create :the_model, name: 'foo', description: "The Foo the_model", 
      created_at: "2013-03-01T00:00:00Z"
    create :the_model, name: 'bar', description: "The Bar the_model", 
      created_at: "2013-06-01T00:00:00Z"
    create :the_model, name: 'baz', description: "The Baz the_model", 
      created_at: "2013-06-10T00:00:00Z"
    create :the_model, name: 'xux', description: "Xux",               
      created_at: "2013-07-01T00:00:00Z"
  end


  it "should return all instances without match args" do
    permit_with 200
    get "/v1/the_models", {}, 
      {'HTTP_ACCEPT' => "application/json", 
       'X-API-Token' => "boy-is-this-fake"}
    expect(response.status).to be(200)
    body = JSON.parse(response.body)
    collection = body['_collection']
    expect(collection['resources'].length).to eq 4
    expect(collection['count']).to eq 4
  end


  it "should perform exact matching on name" do
    permit_with 200
    get "/v1/the_models", {"name" => "foo"}, 
      {'HTTP_ACCEPT' => "application/json", 
       'X-API-Token' => "boy-is-this-fake"}
    expect(response.status).to be(200)
    body = JSON.parse(response.body)
    collection = body['_collection']
    expect(collection['resources'].length).to eq 1
    expect(collection['count']).to eq 1
  end


  it "should perform exact matching on created_at" do
    permit_with 200
    get "/v1/the_models", 
      {"created_at" => "2013-06-10T00:00:00Z"}, 
      {'HTTP_ACCEPT' => "application/json", 
       'X-API-Token' => "boy-is-this-fake"}
    expect(response.status).to be(200)
    body = JSON.parse(response.body)
    collection = body['_collection']
    expect(collection['resources'].length).to eq 1
    expect(collection['count']).to eq 1
  end


  it "should perform range matching on created_at" do
    permit_with 200
    get "/v1/the_models", 
      {"created_at" => "2013-06-01T00:00:00Z,2013-06-30T00:00:00Z"}, 
      {'HTTP_ACCEPT' => "application/json", 
       'X-API-Token' => "boy-is-this-fake"}
    expect(response.status).to be(200)
    body = JSON.parse(response.body)
    collection = body['_collection']
    expect(collection['resources'].length).to eq 2
    expect(collection['count']).to eq 2
  end

end

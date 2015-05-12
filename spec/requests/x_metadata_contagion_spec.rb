require 'spec_helper'

describe "incoming X-Metadata headers", :type => :request do

  before :each do
    permit_with 200
    allow(Api).to receive(:service_token).and_return "fake-token"
    Thread.current[:metadata] = nil
 end

  after :each do
  	Thread.current[:metadata] = nil
  end


  it "should be assigned to @x_metadata" do
    get "/v1/the_models", {}, 
      {'HTTP_ACCEPT' => "application/json", 
       'X-API-Token' => "boy-is-this-fake",
       'X-Metadata'  => "ebola"}
    expect(controller.instance_variable_get(:@x_metadata)).to eq "ebola"
  end

  it "should be assigned to Thread.current[:metadata]" do
    get "/v1/the_models", {}, 
      {'HTTP_ACCEPT' => "application/json", 
       'X-API-Token' => "boy-is-this-fake",
       'X-Metadata'  => "menchikaboola"}
    expect(Thread.current[:metadata]).to eq "menchikaboola"
  end 

  it "should appear in outgoing requests" do
  	# Stub the first call
    stub_request(:get, "http://example.com/some_uri").
         with(:headers => {'Accept'=>'application/json', 
         	               'User-Agent'=>'Ocean', 
         	               'X-Metadata'=>'ebola'}).
         to_return(:status => 200, :body => "{}", :headers => {})
    # Stub the second call
    stub_request(:get, "http://acme.com/some_other_uri").
         with(:headers => {'Accept'=>'application/json', 
         	               'User-Agent'=>'Ocean', 
         	               'X-Api-Token'=>'fake-token', 
         	               'X-Metadata'=>'ebola'}).
         to_return(:status => 200, :body => "{}", :headers => {})    
    # Call the action
    get "/v1/the_models/call_others", {}, 
      {'HTTP_ACCEPT' => "application/json", 
       'X-API-Token' => "boy-is-this-fake",
       'X-Metadata'  => "ebola"}
  end

end

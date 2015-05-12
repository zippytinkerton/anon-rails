#If-None-Match

require 'spec_helper'

describe Api::RemoteResource, :type => :model do

  before :each do
    allow(Api).to receive(:service_token).and_return "the-service_token"

   @original = {"blah"=>{
                    "_links"=>{"self"=>{"href"=>"http://example.com/v1/blahs/1",
                                        "type"=>"application/json"},
                               "quux"=>{"href"=>"http://acme.com/v1/quux/1",
                                        "type"=>"application/json"}
                              },
                    "foo" => 123,
                    "bar" => [1,2,3]
                 }}
    @successful = double success?: true, 
                         headers: {"Content-Type"=>"application/json", "ETag"=>"ORIGINAL"}, 
                         body: @original,
                         status: 200,
                         message: "Success"

    @updated = {"blah"=>{
                    "_links"=>{"self"=>{"href"=>"http://example.com/v1/blahs/1",
                                        "type"=>"application/json"},
                               "quux"=>{"href"=>"http://acme.com/v1/quux/1",
                                        "type"=>"application/json"}
                              },
                    "foo" => "Bibbedy",
                    "bar" => [1,2,3]
                 }}
    @with_etag =  double Api::Response,
                         success?: true, 
                         headers: {"Content-Type"=>"application/json", "ETag"=>"UPDATED"}, 
                         body: @updated,
                         status: 200,
                         message: "Yowza"
    @no_etag =    double success?: true, 
                         headers: {"Content-Type"=>"application/json"}, 
                         body: @updated,
                         status: 200,
                         message: "OK"
    @failed =     double success?: false, 
                         headers: {"Content-Type"=>"application/json"}, 
                         status: 403,
                         message: "Forbidden"
    @unchanged =  double success?: false, 
                         headers: {"Content-Type"=>"application/json", "ETag"=>"IRRELEVANT"}, 
                         status: 304,
                         message: "Not Modified"

     # Make the resource present, with an etag ("ORIGINAL")
     expect(Api).to receive(:request).
       with("http://example.com/v1/blahs/1", :get, args: nil,
       	     :headers=>{}, 
       	     :credentials=>nil, :x_api_token=>"the-service_token", 
       	     :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30).
       and_return(@successful)
     @r = Api::RemoteResource.get "http://example.com/v1/blahs/1"
     expect(@r.etag).to eq "ORIGINAL"
  end


  describe "#refresh!" do

  	it "should return self" do
      expect(@r).to receive :_conditional_get
 	  expect(@r.refresh!).to eq @r
  	end

  	it "should do a normal #get! if the resource isn't present" do
  	  @r.send :present=, false
  	  expect(@r).to receive :get!
 	  @r.refresh!
    end

  	it "should not do a Conditional GET if #etag is blank" do
  	  @r.send :etag=, nil
  	  expect(@r).to receive :get!
 	  @r.refresh!
    end

  	it "should do a Conditional GET if the resource is present and #etag has a value" do
  	  expect(@r).to receive :_conditional_get
  	  @r.refresh!
    end
  end


  describe "#refresh" do

  	it "should return self" do
      expect(@r).to receive :_conditional_get
 	  expect(@r.refresh).to eq @r
  	end

  	it "should do a normal #get if the resource isn't present" do
  	  @r.send :present=, false
  	  expect(@r).to receive :get
 	  @r.refresh
    end

  	it "should not do a Conditional GET if #etag is blank" do
  	  @r.send :etag=, nil
  	  expect(@r).to receive :get
 	  @r.refresh
    end

  	it "should do a Conditional GET if the resource is present and #etag has a value" do
  	  expect(@r).to receive :_conditional_get
  	  @r.refresh
    end

    it "should not raise an exception if _conditional_get raises one" do
      expect(@r).to receive(:_conditional_get).and_raise ZeroDivisionError
      expect { @r.refresh }.not_to raise_error
    end
  end


  describe "#_conditional_get" do

  	before :each do
  	  @conditional = {:headers=>{"If-None-Match"=>"ORIGINAL"}, args: nil,
  	    	            :credentials=>nil, :x_api_token=>"the-service_token", 
  	    	            :retries=>3, :backoff_time=>1, :backoff_rate=>0.9, :backoff_max=>30}
  	end

  	it "should do a GET with the extra If-None-Match header" do
  	  expect(Api).to receive(:request).
  	    with("http://example.com/v1/blahs/1", :get, @conditional).
  	    and_return(@no_etag)
  	  @r.refresh!
  	end


  	describe "when receiving a successful response" do

  	  it "should set response, status, status_message, headers, etag, resource" do
  	  	@r.send :response=, nil
  	  	@r.send :status=, nil
  	  	@r.send :status_message=, nil
  	    expect(Api).to receive(:request).
  	      with("http://example.com/v1/blahs/1", :get, @conditional).
  	      and_return(@with_etag)
  	    @r.refresh!
  	    expect(@r.response).not_to eq nil
  	    expect(@r.status).to eq 200
  	    expect(@r.status_message).to eq "Yowza"
  	    expect(@r.headers).to eq({"Content-Type"=>"application/json", "ETag"=>"UPDATED"})
  	    expect(@r.etag).to eq "UPDATED"
  	    expect(@r.resource).to eq({"_links"=>{"self"=>{"href"=>"http://example.com/v1/blahs/1", 
  	    	                                           "type"=>"application/json"}, 
  	    	                                  "quux"=>{"href"=>"http://acme.com/v1/quux/1", 
  	    	                                  	       "type"=>"application/json"}}, 
  	    	                       "foo"=>"Bibbedy", 
  	    	                       "bar"=>[1, 2, 3]})
  	  end

  	end


  	describe "when receiving a failed response" do

  	  it "should set response, status, status_message, headers, etag" do
  	  	@r.send :response=, nil
  	  	@r.send :status=, nil
  	  	@r.send :status_message=, nil
  	    expect(Api).to receive(:request).
  	      with("http://example.com/v1/blahs/1", :get, @conditional).
  	      and_return(@failed)
  	    expect { @r.refresh! }.to raise_error Api::RemoteResource::ConditionalGetFailed
  	    expect(@r.response).not_to eq nil
  	    expect(@r.status).to eq 403
  	    expect(@r.status_message).to eq "Forbidden"
  	    expect(@r.headers).to eq({"Content-Type"=>"application/json"})
  	    expect(@r.etag).to eq "ORIGINAL"
  	    expect(@r.resource).to eq({"_links"=>{"self"=>{"href"=>"http://example.com/v1/blahs/1", 
  	    	                                           "type"=>"application/json"}, 
  	    	                                  "quux"=>{"href"=>"http://acme.com/v1/quux/1", 
  	    	                                  	       "type"=>"application/json"}}, 
  	    	                       "foo"=>123, 
  	    	                       "bar"=>[1, 2, 3]})
  	  end

  	end


  	describe "when receiving a 304" do

  	  it "should set response and leave everything else as is" do
  	  	@r.send :response=, nil
  	    expect(Api).to receive(:request).
  	      with("http://example.com/v1/blahs/1", :get, @conditional).
  	      and_return(@unchanged)
  	    @r.refresh!
  	    expect(@r.response).not_to eq nil
  	    expect(@r.status).to eq 200
  	    expect(@r.status_message).to eq "Success"
  	    expect(@r.headers).to eq({"Content-Type"=>"application/json", "ETag"=>"ORIGINAL"})
  	    expect(@r.etag).to eq "ORIGINAL"
  	    expect(@r.resource).to eq({"_links"=>{"self"=>{"href"=>"http://example.com/v1/blahs/1", 
  	    	                                           "type"=>"application/json"}, 
  	    	                                  "quux"=>{"href"=>"http://acme.com/v1/quux/1", 
  	    	                                  	       "type"=>"application/json"}}, 
  	    	                       "foo"=>123, 
  	    	                       "bar"=>[1, 2, 3]})
  	  end

  	end



  end

end

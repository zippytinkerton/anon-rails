require 'spec_helper'

require 'base64'


describe Api::Response, :type => :request do

	before :each do
	  @response = Api::Response.new(
	  	double response_code:    200,
	  	       status_message:   "OK",
	  	       response_headers: "Foo: 123\r\nBar: baz\r\nQuux-Zuul: fedcba",
	  	       response_body:    '{"a":1,"b":2}',
	  	       timed_out?:       false,
	  	       success?:         true,
	  	       modified?:        true)
	end


	it "should be instantiatable and take one arg" do
	  expect(@response).to be_an Api::Response
	end

	it "should have a request reader" do
	  expect(@response).to respond_to :request
	end

	it "should have a status reader" do
	  expect(@response.status).to be_an Integer
	end

	it "should have a message reader" do
	  expect(@response.message).to eq "OK"
	end

	it "should have a headers reader" do
	  expect(@response.headers).to eq({"Foo"=>"123", "Bar"=>"baz", "Quux-Zuul"=>"fedcba"})
	end

	it "should have a body reader" do
	  expect(@response.body).to eq({"a"=>1, "b"=>2})
	end

	it "should have a raw_body reader" do
	  expect(@response.raw_body).to eq '{"a":1,"b":2}'
	end

	it "should convert the JSON body only once" do
    expect(JSON).to receive(:parse).exactly(1).times.and_return({"a"=>1,"b"=>2})
	  expect(@response.body).to eq({"a"=>1,"b"=>2})
	  expect(@response.body).to eq({"a"=>1,"b"=>2})
	  expect(@response.body).to eq({"a"=>1,"b"=>2})
	end

	it "should have a success? predicate" do
		expect(@response.success?).to eq true
	end

	it "should have a timed_out? predicate" do
		expect(@response.timed_out?).to eq false
	end

	it "should have a modified? predicate" do
		expect(@response.modified?).to eq true
	end

  it "should throw a JSON::ParseError if the response cannot be parsed as json" do
		error_response = Api::Response.new(
				double response_code:    500,
							 status_message:   "Internal Server Error",
							 response_headers: "Foo: 123\r\nBar: baz\r\nQuux-Zuul: fedcba",
							 response_body:    '<h1>Internal Server Error</h1>',
							 timed_out?:       false,
							 success?:         false,
							 modified?:        true)
		expect {error_response.body}.to raise_error(JSON::ParserError)
	end
end
  

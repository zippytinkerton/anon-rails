require 'spec_helper'

describe "/alive (for Varnish health checking)", :type => :request do

  it "should return a 200 with a body of OK" do
    get "/alive", {}, {'HTTP_ACCEPT' => "application/json"}
    expect(response.status).to be(200)
    expect(response.body).to eq "ALIVE"
  end
  

end

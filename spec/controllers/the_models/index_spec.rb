require 'spec_helper'

describe TheModelsController, :type => :controller do
  
  render_views

  describe "INDEX" do
    
    before :each do
      permit_with 200
      allow(Api).to receive(:ban)
      create :the_model  # page 0
      create :the_model
      create :the_model
      create :the_model

      create :the_model  # page 1
      create :the_model
      create :the_model
      create :the_model

      create :the_model  # page 2
      create :the_model
      request.headers['HTTP_ACCEPT'] = "application/json"
      request.headers['X-API-Token'] = "boy-is-this-fake"
    end

    
    it "should return JSON" do
      get :index
      expect(response.content_type).to eq "application/json"
    end
    
    it "should return a 400 if the X-API-Token header is missing" do
      request.headers['X-API-Token'] = nil
      get :index
      expect(response.status).to eq 400
      expect(response.content_type).to eq "application/json"
    end
    
    it "should return a 200 when successful" do
      get :index
      expect(response.status).to eq 200
      expect(response).to render_template(partial: "_the_model", count: 10)
    end

    it "should return a collection with count, total count, page, page_size, and total_pages" do
      get :index, page_size: 4, page: 0
      expect(response.status).to eq 200
      wrapper = JSON.parse(response.body)
      expect(wrapper).to be_a Hash
      resource = wrapper['_collection']
      expect(resource).to be_a Hash
      coll = resource['resources']
      expect(coll).to be_an Array
      expect(coll.count).to eq 4
      n = resource['count']
      expect(n).to eq 4
      n = resource['total_count']
      expect(n).to eq 10
      n = resource['page']
      expect(n).to eq 0
      n = resource['page_size']
      expect(n).to eq 4
      n = resource['total_pages']
      expect(n).to eq 3
    end

    it "should return a collection with count, total count, page, page_size, and total_pages" do
      get :index, page_size: 5, page: 0
      expect(response.status).to eq 200
      wrapper = JSON.parse(response.body)
      expect(wrapper).to be_a Hash
      resource = wrapper['_collection']
      expect(resource).to be_a Hash
      coll = resource['resources']
      expect(coll).to be_an Array
      expect(coll.count).to eq 5
      n = resource['count']
      expect(n).to eq 5
      n = resource['total_count']
      expect(n).to eq 10
      n = resource['page']
      expect(n).to eq 0
      n = resource['page_size']
      expect(n).to eq 5
      n = resource['total_pages']
      expect(n).to eq 2
    end

    it "should return a collection with a _links array and a self link" do
      get :index
      expect(response.status).to eq 200
      wrapper = JSON.parse(response.body)
      resource = wrapper['_collection']
      links = resource['_links']
      expect(links).to be_a Hash
      expect(links['self']).to be_a Hash
      expect(links['self']['href']).to eq "https://forbidden.example.com/v1/the_models"
      expect(links['self']['type']).to eq "application/json"
    end

    it "should return a paged collection with all hyperlinks" do
      get :index, page_size: 3, page: 2
      expect(response.status).to eq 200
      wrapper = JSON.parse(response.body)
      expect(wrapper).to be_a Hash
      resource = wrapper['_collection']
      expect(resource).to be_a Hash
      links = resource['_links']
      expect(links).to be_a Hash
      expect(links['first_page']).to be_a Hash
      expect(links['first_page']['href']).to eq    "https://forbidden.example.com/v1/the_models?page=0&page_size=3"
      expect(links['last_page']).to be_a Hash
      expect(links['last_page']['href']).to eq     "https://forbidden.example.com/v1/the_models?page=3&page_size=3"
      expect(links['previous_page']).to be_a Hash
      expect(links['previous_page']['href']).to eq "https://forbidden.example.com/v1/the_models?page=1&page_size=3"
      expect(links['next_page']).to be_a Hash
      expect(links['next_page']['href']).to eq     "https://forbidden.example.com/v1/the_models?page=3&page_size=3"
    end

    it "should not include a previous page if already at first page" do
      get :index, page_size: 3, page: 0
      expect(response.status).to eq 200
      wrapper = JSON.parse(response.body)
      expect(wrapper).to be_a Hash
      resource = wrapper['_collection']
      expect(resource).to be_a Hash
      links = resource['_links']
      expect(links).to be_a Hash
      expect(links['previous_page']).to eq nil
    end

    it "should not include a next page if already at last page" do
      get :index, page_size: 4, page: 2
      expect(response.status).to eq 200
      wrapper = JSON.parse(response.body)
      expect(wrapper).to be_a Hash
      resource = wrapper['_collection']
      expect(resource).to be_a Hash
      links = resource['_links']
      expect(links).to be_a Hash
      expect(links['next_page']).to eq nil
    end
  end
  

  describe "INDEX with app and context restriction" do
    
    before :each do
      allow(Api).to receive(:ban)
      create :the_model, app: "foo", context: "quux"
      create :the_model, app: "foo", context: "zuul"
      create :the_model, app: "foo", context: "quux"
      create :the_model, app: nil,   context: nil
      create :the_model, app: nil,   context: "gnik"
      create :the_model, app: "bar", context: "baz"
      create :the_model, app: "bar", context: "gnik"
      create :the_model, app: "foo", context: nil
      create :the_model, app: "xux", context: nil
      request.headers['HTTP_ACCEPT'] = "application/json"
      request.headers['X-API-Token'] = "boy-is-this-fake"
    end

    it "should return all instances if no right restriction is present in the authentication" do
      permit_with 200
      get :index
      expect(response.status).to eq 200
      coll = JSON.parse(response.body)['_collection']['resources']
      expect(coll).to be_an Array
      expect(coll.count).to eq 9
    end

    it "should apply the app restriction if present and context is not or wildcarded" do
      permit_with 200, right: [{"app" => "foo", "context" => "*"}]
      get :index
      expect(response.status).to eq 200
      coll = JSON.parse(response.body)['_collection']['resources']
      expect(coll).to be_an Array
      expect(coll.count).to eq 4
    end

    it "should apply the context restriction if present and app is not or wildcarded" do
      permit_with 200, right: [{"app" => "*", "context" => "gnik"}]
      get :index
      expect(response.status).to eq 200
      coll = JSON.parse(response.body)['_collection']['resources']
      expect(coll).to be_an Array
      expect(coll.count).to eq 2
    end

    it "should apply both the app and the context restrictions if present and not wildcarded" do
      permit_with 200, right: [{"app" => "foo", "context" => "quux"}]
      get :index
      expect(response.status).to eq 200
      coll = JSON.parse(response.body)['_collection']['resources']
      expect(coll).to be_an Array
      expect(coll.count).to eq 2
    end

    it "should handle double app/context clauses" do
      permit_with 200, right: [{"app" => "foo", "context" => "quux"}, 
                               {"app" => "xux", "context" => "*"}
                              ]
      get :index
      expect(response.status).to eq 200
      coll = JSON.parse(response.body)['_collection']['resources']
      expect(coll).to be_an Array
      expect(coll.count).to eq 3
    end

    it "should handle multiple app/context clauses" do
      permit_with 200, right: [{"app" => "foo", "context" => "quux"}, 
                               {"app" => "bar", "context" => "*"},
                               {"app" => "xux", "context" => "*"}
                              ]
      get :index
      expect(response.status).to eq 200
      coll = JSON.parse(response.body)['_collection']['resources']
      expect(coll).to be_an Array
      expect(coll.count).to eq 5
    end


  end

end

require 'spec_helper'

describe "<%= plural_name %>/_<%= singular_name %>" do
  
  before :each do                     # Must be :each (:all causes all tests to fail)
    render partial: "<%= plural_name %>/<%= singular_name %>", locals: {<%= singular_name %>: create(:<%= singular_name %>)}
    @json = JSON.parse(rendered)
    @u = @json['<%= singular_name %>']
    @links = @u['_links'] rescue {}
  end


  it "has a named root" do
    @u.should_not == nil
  end


  it "should have three hyperlinks" do
    @links.size.should == 3
  end

  it "should have a self hyperlink" do
    @links.should be_hyperlinked('self', /<%= plural_name %>/)
  end

  it "should have a creator hyperlink" do
    @links.should be_hyperlinked('creator', /api_users/)
  end

  it "should have an updater hyperlink" do
    @links.should be_hyperlinked('updater', /api_users/)
  end


  it "should have a name" do
    @u['name'].should be_a String
  end

  it "should have a description" do
    @u['description'].should be_a String
  end

  it "should have a created_at time" do
    @u['created_at'].should be_a String
  end

  it "should have an updated_at time" do
    @u['updated_at'].should be_a String
  end

  it "should have a lock_version field" do
    @u['lock_version'].should be_an Integer
  end
      
end

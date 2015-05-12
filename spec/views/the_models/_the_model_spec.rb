require 'spec_helper'

describe "the_models/_the_model", :type => :view do
  
  before :each do                     # Must be :each (:all causes all tests to fail)
    allow(Api).to receive(:ban)
    TheModel.destroy_all
    render partial: "the_models/the_model", locals: {the_model: create(:the_model)}
    @json = JSON.parse(rendered)
    @u = @json['the_model']
    @links = @u['_links'] rescue {}
  end


  it "has a named root" do
    expect(@u).not_to eq nil
  end


  it "should have three hyperlinks" do
    expect(@links.size).to eq 3
  end

  it "should have a self hyperlink" do
    expect(@links).to be_hyperlinked('self', /the_models/)
  end

  it "should have a creator hyperlink" do
    expect(@links).to be_hyperlinked('creator', /api_users/)
  end

  it "should have an updater hyperlink" do
    expect(@links).to be_hyperlinked('updater', /api_users/)
  end


  it "should have a created_at time" do
    expect(@u['created_at']).to be_a String
  end

  it "should have an updated_at time" do
    expect(@u['updated_at']).to be_a String
  end

  it "should have a lock_version field" do
    expect(@u['lock_version']).to be_an Integer
  end

  it "should not have a vip attribute when the authenticating user doesn't belong to the Superuser group" do
    expect(@u['vip']).to eq nil
  end
end


describe "the_models/_the_model", :type => :view do
  
  before :each do                     # Must be :each (:all causes all tests to fail)
    allow(Api).to receive(:ban)
    TheModel.destroy_all
    allow(view).to receive(:member_of_group?).and_return(true)
    render partial: "the_models/the_model", locals: {the_model: create(:the_model, vip: "Rex")}
    @json = JSON.parse(rendered)
    @u = @json['the_model']
  end

  it "should have a visible vip attribute when the authenticating user belongs to the Superuser group" do
    expect(@u['vip']).to eq "Rex"
  end
end

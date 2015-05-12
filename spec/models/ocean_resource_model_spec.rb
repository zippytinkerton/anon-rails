require 'spec_helper'
 
describe TheModel, :type => :model do

  before :each do
    @i = TheModel.new
    @c = @i.class
    @saved_m = @c.varnish_invalidate_member
    @saved_c = @c.varnish_invalidate_collection
    @saved_i = @c.index_only
    @saved_r = @c.ranged_matchers
  end

  after :each do
    @c.ocean_resource_model invalidate_member: @saved_m,
                            invalidate_collection: @saved_c,
                            index: @saved_i,
                            ranged: @saved_r
  end



  it "ocean_resource_model should be available as a class method" do
  	@c.ocean_resource_model
  end
  

  it "should have a collection class method" do
    @c.collection
  end




  it "should accept an :index keyword arg" do
    @c.ocean_resource_model index: [:name]
  end
    
  it ":index should default to [:name]" do
    @c.ocean_resource_model
    expect(@c.index_only).to eq [:name]
  end

  it ":index should be reachable through a class method" do
    @c.ocean_resource_model index: [:foo, :bar]
    expect(@c.index_only).to eq [:foo, :bar]
  end



  it "should accept an :ranged keyword arg" do
    @c.ocean_resource_model ranged: []
  end
    
  it ":ranged should default to []" do
    @c.ocean_resource_model
    expect(@c.ranged_matchers).to eq []
  end

  it ":ranged should be reachable through a class method" do
    @c.ocean_resource_model ranged: [:foo, :bar]
    expect(@c.ranged_matchers).to eq [:foo, :bar]
  end



  it "should accept an :search keyword arg" do
  	@c.ocean_resource_model search: :description
  end
    
  it ":search should default to :description" do
  	@c.ocean_resource_model
  	expect(@c.index_search_property).to eq :description
  end

  it ":search should be reachable through a class method" do
  	@c.ocean_resource_model search: :zalagadoola
  	expect(@c.index_search_property).to eq :zalagadoola
  end



  it "should accept a :page_size keyword arg" do
    @c.ocean_resource_model page_size: 100
  end

  it ":page_size should default to 25" do
    @c.ocean_resource_model
    expect(@c.collection_page_size).to eq 25
  end

  it ":page_size should be reachable through a class method" do
    @c.ocean_resource_model page_size: 10
    expect(@c.collection_page_size).to eq 10
  end



  it "should have a latest_api_version class method" do
  	expect(@c.latest_api_version).to eq "v1"
  end



  it "should have an instance method to touch two instances" do
  	other = TheModel.new
  	expect(@i).to receive(:touch).once
  	expect(other).to receive(:touch).once
  	@i.touch_both(other)
  end


  it "should accept an :invalidate_collection keyword arg" do
    @c.ocean_resource_model invalidate_collection: ['$', '?']
  end

  it ":invalidate_collection should default to INVALIDATE_COLLECTION_DEFAULT" do
    @c.ocean_resource_model
    expect(@c.varnish_invalidate_collection).to eq INVALIDATE_COLLECTION_DEFAULT
  end

  it ":invalidate_collection should be reachable through a class method" do
    @c.ocean_resource_model invalidate_collection: ['a', 'b', 'c']
    expect(@c.varnish_invalidate_collection).to eq ['a', 'b', 'c']
  end

  it "should have a class method to invalidate all collections in Varnish" do
    allow(Api).to receive(:ban)
    @c.invalidate
  end

  it "the invalidation class method should use the suffixes defined by :invalidate_collection" do
    expect(Api).to receive(:ban).with("/v[0-9]+/the_models" + INVALIDATE_COLLECTION_DEFAULT.first)
    @c.invalidate
  end


  it "should accept an :invalidate_member keyword arg" do
    @c.ocean_resource_model invalidate_member: ['/', '$', '?']
  end

  it ":invalidate_member should default to INVALIDATE_MEMBER_DEFAULT" do
    @c.ocean_resource_model
    expect(@c.varnish_invalidate_member).to eq INVALIDATE_MEMBER_DEFAULT
  end

  it ":invalidate_member should be reachable through a class method" do
    @c.ocean_resource_model invalidate_member: ['x', 'y', 'z']
    expect(@c.varnish_invalidate_member).to eq ['x', 'y', 'z']
  end

  it "should have an instance method to invalidate itself in Varnish" do
    allow(Api).to receive(:ban)
    @i.invalidate
  end

  it "the invalidation instance method should use the suffixes defined by :invalidate_member AND :invalidate_collection" do
    # The basic collection
    expect(Api).to receive(:ban).once.with("/v[0-9]+/the_models#{INVALIDATE_COLLECTION_DEFAULT.first}")
    # The member itself and its subordinate relations/collections
    expect(Api).to receive(:ban).once.with("/v[0-9]+/the_models/#{@i.id}#{INVALIDATE_MEMBER_DEFAULT.first}")
    # The lambda
    expect(Api).to receive(:ban).once.with("/v[0-9]+/foo/bar/baz($|?)")
    # Do it!
    @i.invalidate
  end


  it "should accept a :create_timestamp keyword arg" do
    @c.ocean_resource_model create_timestamp: :first_spawned_at
  end

  it ":create_timestamp should default to :created_at" do
    @c.ocean_resource_model
    expect(@c.create_timestamp).to eq :created_at
  end

  it ":create_timestamp should be reachable through a class method" do
    @c.ocean_resource_model create_timestamp: :first_spawned_at
    expect(@c.create_timestamp).to eq :first_spawned_at
  end


  it "should accept an :update_timestamp keyword arg" do
    @c.ocean_resource_model update_timestamp: :last_fucked_up_at
  end

  it ":update_timestamp should default to :updated_at" do
    @c.ocean_resource_model
    expect(@c.update_timestamp).to eq :updated_at
  end

  it ":update_timestamp should be reachable through a class method" do
    @c.ocean_resource_model update_timestamp: :last_fucked_up_at
    expect(@c.update_timestamp).to eq :last_fucked_up_at
  end


end

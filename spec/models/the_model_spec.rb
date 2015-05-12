# == Schema Information
#
# Table name: the_models
#
#  id           :integer          not null, primary key
#  name         :string(255)      not null
#  description  :string(255)      default(""), not null
#  lock_version :integer          default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  created_by   :integer          default(0), not null
#  updated_by   :integer          default(0), not null
#

require 'spec_helper'

describe TheModel, :type => :model do

  before :each do
    allow(Api).to receive(:ban)
  end

  
  describe "attributes" do
    
    it "should include a name" do
      expect(create(:the_model, name: "the_model_a").name).to eq "the_model_a"
    end

    it "should include a description" do
      expect(create(:the_model, name: "blah", description: "A the_model description").description).to eq "A the_model description"
    end
    
    it "should include a lock_version" do
      expect(create(:the_model, lock_version: 24).lock_version).to eq 24
    end
    
    it "should have a creation time" do
      expect(create(:the_model).created_at).to be_a Time
    end

    it "should have an update time" do
      expect(create(:the_model).updated_at).to be_a Time
    end
  
   it "should have a creator" do
      expect(create(:the_model, created_by: 123).created_by).to be_an Integer
    end

    it "should have an updater" do
      expect(create(:the_model, updated_by: 123).updated_by).to be_an Integer
    end

    it "should have an app attribute" do
      expect(create(:the_model, app: "foo").app).to eq "foo"
    end

    it "should have a context attribute" do
      expect(create(:the_model, context: "bar").context).to eq "bar"
    end

 end
    

  describe "search" do
  
    describe ".collection" do
    
      before :each do
        create :the_model, name: 'foo', description: "The Foo the_model", 
          created_at: "2013-03-01T00:00:00Z", created_by: 10, score: 10.0
        create :the_model, name: 'bar', description: "The Bar the_model", 
          created_at: "2013-06-01T00:00:00Z", created_by: 20, score: 20.0
        create :the_model, name: 'baz', description: "The Baz the_model", 
          created_at: "2013-06-10T00:00:00Z", created_by: 30, score: 30.0
        create :the_model, name: 'xux', description: "Xux",               
          created_at: "2013-07-01T00:00:00Z", created_by: 40, score: 40.0
      end

    
      it "should return an array of TheModel instances" do
        ix = TheModel.collection
        expect(ix.length).to eq 4
        expect(ix[0]).to be_a TheModel
      end
    
      it "should allow matches on name" do
        expect(TheModel.collection(name: 'NOWAI').length).to eq 0
        expect(TheModel.collection(name: 'bar').length).to eq 1
        expect(TheModel.collection(name: 'baz').length).to eq 1
      end
      
      it "should allow searches on description" do
        expect(TheModel.collection(search: 'B').length).to eq 2
        expect(TheModel.collection(search: 'the_model').length).to eq 3
      end

      it "should return an empty collection when using search where it's been disabled" do
        allow(TheModel).to receive_messages(index_search_property: false)
        expect(TheModel.collection(search: 'B').length).to eq 0
        expect(TheModel.collection(search: 'the_model').length).to eq 0
      end
      
      it "key/value pairs not in the index_only array should quietly be ignored" do
        expect(TheModel.collection(name: 'bar', aardvark: 12).length).to eq 1
      end

      it "should support pagination" do
        expect(TheModel.collection(page: 0, page_size: 2).order("name DESC").pluck(:name)).to eq ["xux", "foo"]
        expect(TheModel.collection(page: 1, page_size: 2).order("name DESC").pluck(:name)).to eq ["baz", "bar"]
        expect(TheModel.collection(page: 2, page_size: 2)).to eq []
        expect(TheModel.collection(page: -1, page_size: 2)).to eq []
      end


      it "should allow ranged matches on datetimes" do
        expect(TheModel.collection(created_at: "2013-04-01T00:00:00Z,2013-06-30T00:00:00Z").length).to eq 2
        expect(TheModel.collection(created_at: "2013-06-01T00:00:00Z,2013-07-01T00:00:00Z").length).to eq 3
        expect(TheModel.collection(created_at: "2013-01-01T00:00:00Z,2013-12-31T23:59:59Z").length).to eq 4
      end

      it "should allow ranged matches on integers" do
        expect(TheModel.collection(created_by: "15,35").length).to eq 2
        expect(TheModel.collection(created_by: "10,10").length).to eq 1
        expect(TheModel.collection(created_by: "100,200").length).to eq 0
      end
        
      it "should allow ranged matches on floats" do
        expect(TheModel.collection(score: "15.0,35.76").length).to eq 2
        expect(TheModel.collection(score: "10.0,10.00").length).to eq 1
        expect(TheModel.collection(score: "100.0,200.0").length).to eq 0
      end
        
      it "should allow ranged matches on strings" do
        expect(TheModel.collection(name: "bad,bba").length).to eq 2
        expect(TheModel.collection(name: "xux,xux").length).to eq 1
        expect(TheModel.collection(name: "a,z").length).to eq 4
      end
        
    end
  end

end

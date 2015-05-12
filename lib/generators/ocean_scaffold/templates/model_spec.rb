require 'spec_helper'

describe <%= class_name %> do


  describe "attributes" do
    
    it "should have a name" do
      create(:<%= singular_name %>).name.should be_a String
    end

    it "should have a description" do
      create(:<%= singular_name %>).description.should be_a String
    end

     it "should have a creation time" do
      create(:<%= singular_name %>).created_at.should be_a Time
    end

    it "should have an update time" do
      create(:<%= singular_name %>).updated_at.should be_a Time
    end
  
   it "should have a creator" do
      create(:<%= singular_name %>).created_by.should be_an Integer
    end

    it "should have an updater" do
      create(:<%= singular_name %>).updated_by.should be_an Integer
    end

  end


  describe "relations" do

  end



  describe "search" do
  
    describe ".collection" do
    
      before :each do
        create :<%= singular_name %>, name: 'foo', description: "The Foo object"
        create :<%= singular_name %>, name: 'bar', description: "The Bar object"
        create :<%= singular_name %>, name: 'baz', description: "The Baz object"
      end
      
    
      it "should return an array of <%= class_name %> instances" do
        ix = <%= class_name %>.collection
        ix.length.should == 3
        ix[0].should be_a <%= class_name %>
      end
    
      it "should allow matches on name" do
        <%= class_name %>.collection(name: 'NOWAI').length.should == 0
        <%= class_name %>.collection(name: 'bar').length.should == 1
        <%= class_name %>.collection(name: 'baz').length.should == 1
      end
      
      it "should allow searches on description" do
        <%= class_name %>.collection(search: 'a').length.should == 2
        <%= class_name %>.collection(search: 'object').length.should == 3
      end
      
      it "key/value pairs not in the index_only array should quietly be ignored" do
        <%= class_name %>.collection(name: 'bar', aardvark: 12).length.should == 1
      end
        
    end
  end

end

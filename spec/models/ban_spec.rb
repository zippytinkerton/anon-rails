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

  it "should have a varnish_invalidate_member list of two items" do
    expect(TheModel.varnish_invalidate_member.length).to eq 2
  end

  it "should have a varnish_invalidate_collection list of one item" do
    expect(TheModel.varnish_invalidate_collection.length).to eq 1
  end


  it "should trigger two BANs when created" do
    expect(Api).to receive(:ban).once.with("/v[0-9]+/the_models#{INVALIDATE_COLLECTION_DEFAULT.first}")
    expect(Api).to receive(:ban).once.with("/v[0-9]+/foo/bar/baz($|?)")
  	create :the_model
  end


  it "should trigger three BANs when updated" do
    allow(Api).to receive(:ban)
  	m = create :the_model
    expect(Api).to receive(:ban).once.with("/v[0-9]+/the_models#{INVALIDATE_COLLECTION_DEFAULT.first}")
    expect(Api).to receive(:ban).once.with("/v[0-9]+/the_models/#{m.id}#{INVALIDATE_MEMBER_DEFAULT.first}")
    expect(Api).to receive(:ban).once.with("/v[0-9]+/foo/bar/baz($|?)")
    m.name = "Zalagadoola"
 	  m.save!
  end


  it "should trigger three BANs when touched" do
    allow(Api).to receive(:ban)
  	m = create :the_model
    expect(Api).to receive(:ban).once.with("/v[0-9]+/the_models#{INVALIDATE_COLLECTION_DEFAULT.first}")
    expect(Api).to receive(:ban).once.with("/v[0-9]+/the_models/#{m.id}#{INVALIDATE_MEMBER_DEFAULT.first}")
    expect(Api).to receive(:ban).once.with("/v[0-9]+/foo/bar/baz($|?)")
 	  m.touch
  end


  it "should trigger three BANs when destroyed" do
    allow(Api).to receive(:ban)
  	m = create :the_model
    expect(Api).to receive(:ban).once.with("/v[0-9]+/the_models#{INVALIDATE_COLLECTION_DEFAULT.first}")
    expect(Api).to receive(:ban).once.with("/v[0-9]+/the_models/#{m.id}#{INVALIDATE_MEMBER_DEFAULT.first}")
    expect(Api).to receive(:ban).once.with("/v[0-9]+/foo/bar/baz($|?)")
  	m.destroy
  end

end

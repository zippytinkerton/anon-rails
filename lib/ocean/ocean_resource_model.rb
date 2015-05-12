module Ocean
  module OceanResourceModel
    
    extend ActiveSupport::Concern

    included do
      # Inheritable invalidation callbacks
      after_create  { |model| model.try(:invalidate, true) }
      after_update  { |model| model.try(:invalidate) }
      after_touch   { |model| model.try(:invalidate) }
      after_destroy { |model| model.try(:invalidate) }
    end


    module ClassMethods

      #
      # The presence of +ocean_resource_model+ in a Rails ActiveRecord model declares
      # that the model is an Ocean resource. It takes five keyword parameters:
      #
      # +index+: defaults to <code>[:name]</code>. Enumerates the model attributes which
      # may be used for parameter matching and grouping.
      #
      # +ranged+: defaults to <code>[]</code>. An array of attributes which should accept
      # ranges in collection match operations.
      #
      # +search+: defaults to +:description+. Names the model attribute used for substring
      # searches. The attribute must be a string or text attribute.
      #
      # +page_size+: defaults to 25. When paginated collections are retrieved, this will
      # be the default page_size for this resource.
      #
      # +invalidate_member+: defaults to +INVALIDATE_MEMBER_DEFAULT+. An array of strings
      # enumerating the Varnish +BAN+ HTTP request URI suffixes to use to invalidate a
      # resource member, including any relations derived from it.
      #
      # +invalidate_collection+: defaults to +INVALIDATE_COLLECTION_DEFAULT+. An array of strings
      # enumerating the Varnish +BAN+ HTTP request URI suffixes to use to invalidate a
      # collection of resources.
      #
      # +create_timestamp+ and +update_timestamp+ default to +:created_at+ and +:updated_at+,
      # respectively, naming the attribute containing the timestamps for resource creation
      # and modification. Either one may be nil or false.
      #
      def ocean_resource_model(index:                 [:name],
                               ranged:                [],
      	                       search:                :description,
                               page_size:             25,
                               invalidate_member:     INVALIDATE_MEMBER_DEFAULT,
                               invalidate_collection: INVALIDATE_COLLECTION_DEFAULT,
                               create_timestamp:      :created_at,
                               update_timestamp:      :updated_at
      	                      )
      	include ApiResource
      	cattr_accessor :index_only
        cattr_accessor :ranged_matchers
      	cattr_accessor :index_search_property
        cattr_accessor :collection_page_size
        cattr_accessor :varnish_invalidate_member
        cattr_accessor :varnish_invalidate_collection
        cattr_accessor :create_timestamp
        cattr_accessor :update_timestamp
        self.index_only = index
        self.ranged_matchers = ranged
        self.index_search_property = search
        self.collection_page_size = page_size
        self.varnish_invalidate_member = invalidate_member
        self.varnish_invalidate_collection = invalidate_collection
        self.create_timestamp = create_timestamp
        self.update_timestamp = update_timestamp
      end
    end
  end
end


ActiveRecord::Base.send(:include, Ocean::OceanResourceModel) if defined? ActiveRecord
OceanDynamo::Table.send(:include, Ocean::OceanResourceModel) if defined? OceanDynamo

#
# This is an "acts_as" type method to be used in ActiveRecord model
# definitions: "ocean_resource_controller".
#

module Ocean

  #
  # This module is included in ActionController::Base. The most notable effect
  # is that the class method +ocean_resource_controller+ becomes available, and that
  # rescue_from handlers are added to handle exceptions for non-unique, stale, and
  # invalid records. These all terminate the current action and return standard
  # JSON API errors and validation errors. This allows +POST+ and +PUT+ actions
  # to be written in a very terse, clear and understandable manner.
  #
  module OceanResourceController
    
    extend ActiveSupport::Concern

    included do
      if defined? ActiveRecord
        rescue_from ActiveRecord::RecordNotUnique, 
                    ActiveRecord::StatementInvalid do |x|
          render_api_error 422, "Resource not unique"
        end

        rescue_from ActiveRecord::StaleObjectError do |x|
          render_api_error 409, "Stale #{x.record.class.name}"
        end

        rescue_from ActiveRecord::RecordInvalid do |x|
          render_validation_errors x.record, except: ocean_resource_controller_no_validation_errors_on
        end
      end

      if defined? OceanDynamo
        rescue_from OceanDynamo::RecordNotUnique do |x|
          render_api_error 422, "Resource not unique"
        end

        rescue_from OceanDynamo::StaleObjectError do |x|
          render_api_error 409, "Stale #{x.record.class.name}"
        end

        rescue_from OceanDynamo::RecordInvalid do |x|
          render_validation_errors x.record, except: ocean_resource_controller_no_validation_errors_on
        end
      end
    end

    module ClassMethods

      #
      # The presence of +ocean_resource_controller+ in a Rails controller declares
      # that the controller is an Ocean controller handling an Ocean resource. It takes
      # three optional keyword parameters:
      #
      # +required_attributes+: a list of keywords naming model attributes which must be
      # present. If an API consumer submits data where any of these attributes isn't present, 
      # an API error will be generated.
      #
      #   ocean_resource_controller required_attributes: [:lock_version, :title]
      #
      # +permitted_attributes+: a list of keywords naming model attributes which may be
      # present. Attributes not in +permitted_attributes+ or +required_attributes+ will be
      # filtered away.
      #
      # +no_validation_errors_on+: a symbol, string, or an array of symbols and strings. Error
      # descriptions in 422 responses will not include the enumerated attributes. This
      # is sometimes useful for purely internal attributes which should never appear
      # in error descriptions.
      #
      #   ocean_resource_controller no_validation_errors_on: [:password_hash, :password_salt]
      #
      # +extra_actions+: a hash containing information about extra controller actions
      # apart from the standard Rails ones of +index+, +show+, +create+, +update+, and 
      # +destroy+. One entry per extra action is required in order to process authentication
      # requests. Here's an example:
      #
      #   ocean_resource_controller extra_actions: {'comments' =>       ['comments', "GET"],
      #                                             'comment_create' => ['comments', "POST"]}
      #
      # The above example declares that the controller has two non-standard actions called
      # +comments+ and +comments_create+, respectively. Their respective values indicate that
      # +comments+ will be called as the result of a +GET+ to the +comments+ hyperlink, and
      # that +comment_create+ will be called as the result of a +POST+ to the same hyperlink.
      # Thus, +extra_actions+ maps actions to hyperlink names and HTTP methods.
      #
      def ocean_resource_controller(required_attributes:     [:lock_version, :name, :description],
                                    permitted_attributes:    [],
                                    no_validation_errors_on: [],
                                    extra_actions:           {}
      	                           )
      	cattr_accessor :ocean_resource_controller_extra_actions
        cattr_accessor :ocean_resource_controller_required_attributes
        cattr_accessor :ocean_resource_controller_permitted_attributes
        cattr_accessor :ocean_resource_controller_no_validation_errors_on
      	self.ocean_resource_controller_extra_actions = extra_actions
        self.ocean_resource_controller_required_attributes = required_attributes
        self.ocean_resource_controller_permitted_attributes = permitted_attributes
        self.ocean_resource_controller_no_validation_errors_on = no_validation_errors_on
      end
    end


    #
    # Used in controller code internals to obtain the extra actions declared using
    # +ocean_resource_controller+.
    #
    def extra_actions
      self.class.ocean_resource_controller_extra_actions
    end


    #
    # Returns true if the params hash lacks a required attribute declared using
    # +ocean_resource_controller+.
    #
    def missing_attributes?
      self.class.ocean_resource_controller_required_attributes.each do |attr|
        return true unless params[attr]
      end
      return false
    end

  end
end


ActionController::Base.send :include, Ocean::OceanResourceController

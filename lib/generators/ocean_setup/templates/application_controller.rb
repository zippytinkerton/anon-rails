class ApplicationController < ActionController::Base

  include OceanApplicationController

  before_action :require_x_api_token
  before_action :authorize_action
    
end

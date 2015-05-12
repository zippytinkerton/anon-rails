class ErrorsController < ApplicationController
  
  skip_before_action :require_x_api_token
  skip_before_action :authorize_action
  
  
  def show
    @exception       = env['action_dispatch.exception']
    @status_code     = ActionDispatch::ExceptionWrapper.new(env, @exception).status_code
    #@rescue_response = ActionDispatch::ExceptionWrapper.rescue_responses[@exception.class.name]
    render_api_error @status_code, @exception.message
  end  
  
end

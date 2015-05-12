class AliveController < ApplicationController

  skip_before_action :require_x_api_token
  skip_before_action :authorize_action


  def index
    # If there is a DB, call to it here to ensure it too is healthy
    render text: "ALIVE", status: 200
  end

end

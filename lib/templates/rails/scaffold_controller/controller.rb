<% if namespaced? -%>
require_dependency "<%= namespaced_file_path %>/application_controller"

<% end -%>
<% module_namespacing do -%>
class <%= controller_class_name %>Controller < ApplicationController

  ocean_resource_controller required_attributes: [:lock_version, :name, :description]

  before_action :find_<%= singular_table_name %>, :only => [:show, :update, :destroy]
    
  
  # GET <%= route_url %>
  def index
    expires_in 0, 's-maxage' => 30.minutes
    if stale?(collection_etag(<%= class_name %>))
      api_render <%= class_name %>.collection(params)
    end
  end


  # GET <%= route_url %>/1
  def show
    expires_in 0, 's-maxage' => 30.minutes
    if stale?(@<%= singular_table_name %>)
      api_render @<%= singular_table_name %>
    end
  end


  # POST <%= route_url %>
  def create
    @<%= singular_table_name %> = <%= class_name %>.new(filtered_params <%= class_name %>)
    set_updater(@<%= singular_table_name %>)
    @<%= singular_table_name %>.save!
    api_render @<%= singular_table_name %>, new: true
  end


  # PUT <%= route_url %>/1
  def update
    if missing_attributes?
      render_api_error 422, "Missing resource attributes"
      return
    end
    @<%= singular_table_name %>.assign_attributes(filtered_params <%= class_name %>)
    set_updater(@<%= singular_table_name %>)
    @<%= singular_table_name %>.save!
    api_render @<%= singular_table_name %>
  end


  # DELETE <%= route_url %>/1
  def destroy
    @<%= orm_instance.destroy %>
    render_head_204
  end
  
  
  private
     
  def find_<%= singular_table_name %>
    @<%= singular_table_name %> = <%= class_name %>.find_by_id params[:id]
    # If your table has app and context columns and you have created Rights utilising them,
    # comment out the line above this comment and uncomment the following one:
    #@<%= singular_table_name %> = add_right_restrictions(<%= class_name %>.where(id: params[:id]), @right_restrictions).first
    return true if @<%= singular_table_name %>
    render_api_error 404, "<%= class_name %> not found"
    false
  end
    
end
<% end -%>

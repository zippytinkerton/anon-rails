class OceanScaffoldGenerator < Rails::Generators::NamedBase #:nodoc: all
  
  source_root File.expand_path('../templates', __FILE__)
  
  def extend_model
    inject_into_class "#{Rails.root}/app/models/#{singular_name}.rb", 
      class_name.constantize,
      "
  ocean_resource_model index: [:name], search: :description


  # Relations


  # Attributes


  # Validations
  
  
"
  end
  
  def add_model_specs
    template "model_spec.rb", "#{Rails.root}/spec/models/#{singular_name}_spec.rb"
  end
  
  def remove_html_controller_specs
    remove_file "spec/controllers/#{plural_name}_controller_spec.rb"
  end
  
 def add_json_controller_specs
    template "controller_specs/delete_spec.rb", "#{Rails.root}/spec/controllers/#{plural_name}/delete_spec.rb"
    template "controller_specs/show_spec.rb",   "#{Rails.root}/spec/controllers/#{plural_name}/show_spec.rb"
    template "controller_specs/index_spec.rb",  "#{Rails.root}/spec/controllers/#{plural_name}/index_spec.rb"
    template "controller_specs/create_spec.rb", "#{Rails.root}/spec/controllers/#{plural_name}/create_spec.rb"
    template "controller_specs/update_spec.rb", "#{Rails.root}/spec/controllers/#{plural_name}/update_spec.rb"
  end
  
   def remove_html_views
    remove_file "app/views/#{plural_name}/_form.html.erb"
    remove_file "app/views/#{plural_name}/edit.html.erb"
    remove_file "app/views/#{plural_name}/index.html.erb"
    remove_file "app/views/#{plural_name}/index.json.jbuilder"
    remove_file "app/views/#{plural_name}/new.html.erb"
    remove_file "app/views/#{plural_name}/show.html.erb"
    remove_file "app/views/#{plural_name}/show.json.jbuilder"
  end
  
  def add_json_views
    template "views/_resource.json.jbuilder", "#{Rails.root}/app/views/#{plural_name}/_#{singular_name}.json.jbuilder"
  end
  
  def remove_html_view_specs
    remove_file "spec/views/#{plural_name}/index.html.erb_spec.rb"
    remove_file "spec/views/#{plural_name}/show.html.erb_spec.rb"
    remove_file "spec/views/#{plural_name}/new.html.erb_spec.rb"
    remove_file "spec/views/#{plural_name}/create.html.erb_spec.rb"
    remove_file "spec/views/#{plural_name}/update.html.erb_spec.rb"
    remove_file "spec/views/#{plural_name}/edit.html.erb_spec.rb"
  end
  
  def add_json_view_spec
    template "view_specs/_resource_spec.rb", "#{Rails.root}/spec/views/#{plural_name}/_#{singular_name}_spec.rb"
  end
  
  def remove_request_specs
    remove_file "spec/requests/#{plural_name}_spec.rb"
  end
  
  def update_routing_specs
    remove_file "spec/routing/#{plural_name}_routing_spec.rb"
    template "resource_routing_spec.rb", "#{Rails.root}/spec/routing/#{plural_name}_routing_spec.rb"
  end
  
end

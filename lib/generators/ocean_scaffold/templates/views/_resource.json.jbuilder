json.<%= singular_name %> do |json|
	json._links       hyperlinks(self:    <%= singular_name %>_url(<%= singular_name %>),
	                             creator: api_user_url(<%= singular_name %>.created_by),
	                             updater: api_user_url(<%= singular_name %>.updated_by))
	json.(<%= singular_name %>, :lock_version, :name, :description) 
	json.created_at   <%= singular_name %>.created_at.utc.iso8601
	json.updated_at   <%= singular_name %>.updated_at.utc.iso8601
end

json.the_model do |json|
	json._links       hyperlinks(self:    the_model_url(the_model),
	                             creator: api_user_url(the_model.created_by),
	                             updater: api_user_url(the_model.updated_by))
	json.(the_model, :lock_version) 
	json.vip          the_model.vip if superuser?
	json.created_at   the_model.created_at.utc.iso8601
	json.updated_at   the_model.updated_at.utc.iso8601
end

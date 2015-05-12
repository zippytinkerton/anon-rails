module ApplicationHelper

  #
  # Used in Jbuilder templates to build hyperlinks
  #
  def hyperlinks(links={})
    result = {}
    links.each do |qi, val|
      next unless val.present?
      result[qi.to_s] = { 
                 "href" => val.kind_of?(String) ? val : val[:href], 
                 "type" => val.kind_of?(String) ? "application/json" : val[:type]
              }
    end
    result
  end
  

  #
  # This is needed everywhere except inside the Auth service to render creator
  # and updater links correctly.
  #
  def api_user_url(x)
    if x.blank?
      "#{OCEAN_API_URL}/#{Api.version_for :api_user}/api_users/0"
    elsif x.is_a?(Integer)
      "#{OCEAN_API_URL}/#{Api.version_for :api_user}/api_users/#{x}"
    elsif x.is_a?(String)
      x
    else
      raise "api_user_url takes an integer, a string, or nil"
    end
  end


  #
  # View helper predicates to determine if the ApiUser behind the current
  # authorisation belongs to one or more of a list of Groups.
  #
  def member_of_group?(*names)
    @group_names && @group_names.intersect?(names.to_set) 
  end

  #
  # Returns true if the ApiUser behind the current authorisation belongs 
  # to the Ocean Group "Superusers".
  #
  def superuser?
    member_of_group?("Superusers")
  end
end

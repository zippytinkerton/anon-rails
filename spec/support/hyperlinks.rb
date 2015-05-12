RSpec::Matchers.define :be_hyperlinked do |link, regex, type="application/json"|

  match do |hyperlinks|
    (@h = hyperlinks[link]) && 
    (@h['href'] =~ regex) &&
    (@h['type'] == type)
  end


  failure_message do |actual|
    "expected the resource representation to " + description
  end

  description do
    result = "have a '#{link}' hyperlink"
    result += " containing '#{regex.source}' in the URI" unless @h['href'] =~ regex
    result += " leading to a resource of type '#{type}' (was '#{@h['type']}')" unless @h['type'] == type
    result
  end


end

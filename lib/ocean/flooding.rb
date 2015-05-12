# # Rack::Attack.blacklist('block 1.2.3.4') do |req|
# #   true
# # end

# Rack::Attack.blacklisted_response = lambda do |env|
#   [ 403, {}, ['Blacklisted']]
# end


# Rack::Attack.throttle('req/ip', :limit => 1000, :period => 1.second) do |req|
#   # If the return value is truthy, the cache key for the return value
#   # is incremented and compared with the limit. In this case:
#   #   "rack::attack:#{Time.now.to_i/1.second}:req/ip:#{req.ip}"
#   # We might want to use the token value instead of the #{req.ip} value.
#   # (IPs may be shared, tokens never are.)
#   #
#   # If falsy, the cache key is neither incremented nor checked.
#   req.ip
# end

# Rack::Attack.throttled_response = lambda do |env|
#   allowed =     env['rack.attack.match_data'][:limit]
#   t =           env['rack.attack.match_data'][:period].inspect
#   made =        env['rack.attack.match_data'][:count]
#   retry_after = env['rack.attack.match_data'][:period] rescue nil
#   [ 429, 
#     {'Retry-After' => retry_after.to_s}, 
#     ["Too Many Requests. You have exceeded your quota of #{allowed} request(s)/#{t} by #{made - allowed}."]]
# end

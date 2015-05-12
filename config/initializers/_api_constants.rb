# The is the example file
ef = File.join(Rails.root, "config/config.yml.example")

# Only load config data if there is an example file
if File.exists?(ef)

  # This is the tailored file, not under source control.
  f = File.join(Rails.root, "config/config.yml")

  # If the tailored file doesn't exist, and we're running under TeamCity, 
  # use the example file as-is.
  unless File.exists?(f)
    f = ENV['OCEAN_API_HOST'] ? ef : false
  end

  # If there is a file to process, do so
  if f
    cfg = YAML.load(ERB.new(File.read(f)).result)
    cfg.merge! cfg.fetch(Rails.env, {}) if cfg.fetch(Rails.env, {})
    cfg.each do |k, v|
      next if k =~ /[a-z]/
      override = ENV["OVERRIDE_#{k}"]
      if override && override != ""
        master, staging = override.split(',')
        if staging.present? && k == "API_PASSWORD"
          pw = (ENV['GIT_BRANCH'] == 'staging' ? staging : master)
          eval "#{k} = #{pw.inspect}"
        else
          eval "#{k} = #{override.inspect}"
        end
      else
        eval "#{k} = #{v.inspect}"
      end
    end
  else
    # Otherwise print an error message and abort.
    puts
    puts "-----------------------------------------------------------------------"
    puts "Constant definition file missing. Please copy config/config.yml.example"
    puts "to config/config.yml and tailor its contents to suit your dev setup."
    puts
    puts "NB: config.yml is excluded from git version control as it will contain"
    puts "    data private to your Ocean system."
    puts "-----------------------------------------------------------------------"
    puts
    abort
  end

end

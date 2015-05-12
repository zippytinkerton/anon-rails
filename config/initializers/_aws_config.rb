# Check if the ENV vars are set; if so, don't read any file
if (ENV['AWS_ACCESS_KEY_ID'].present? &&
    ENV['AWS_SECRET_ACCESS_KEY'].present? &&
    ENV['AWS_REGION'].present?)
  #AWS.config if defined? AWS
  #Aws.config if defined? Aws
else

  # The is the example file
  ef = File.join(Rails.root, "config/aws.yml.example")

  # Only load AWS data if there is an example file
  if File.exists?(ef)

    # This is the tailored file, not under source control.
    f = File.join(Rails.root, "config/aws.yml")
    
    # If the tailored file doesn't exist, and we're running in test mode
    # (which is the case under TeamCity), use the example file as-is.
    unless File.exists?(f)
      f = ENV['OCEAN_API_HOST'] ? ef : false
    end

    # If there is a file to process, do so
    if f
      options = YAML.load(File.read(f))[Rails.env]
      ENV['AWS_ACCESS_KEY_ID'] = options[:access_key_id] || options['access_key_id']
      ENV['AWS_SECRET_ACCESS_KEY'] = options[:secret_access_key] || options['secret_access_key']
      ENV['AWS_REGION'] = options[:region] || options['region']
      #AWS.config options if defined? AWS
      #Aws.config = options if defined? Aws
    else
      # Otherwise print an error message and abort.
      puts
      puts "-----------------------------------------------------------------------"
      puts "AWS config file missing. Please copy config/aws.yml.example"
      puts "to config/aws.yml and tailor its contents to suit your dev setup."
      puts "Alternatively export environment variables AWS_ACCESS_KEY_ID,"
      puts "AWS_SECRET_ACCESS_KEY, and AWS_REGION."
      puts
      puts "NB: aws.yml is excluded from git version control as it will contain"
      puts "    data private to your Ocean system."
      puts "-----------------------------------------------------------------------"
      puts
      abort
    end
  end
end

require 'socket'

#
# This class is a drop-in replacement for the standard Rails logger. It is
# used in production only and uses ZeroMQ as an intelligent, high-capacity
# transport. ZeromqLogger implements enough of the Logger interface to allow
# it to override the standard logger.
#
class ZeromqLogger

  attr_accessor :level, :formatter

  #
  # Obtains the IP of the current process, initialises the @logger object
  # by instantiating a ZeroLog object which then is used to set up the
  # log data sender.
  #
  def initialize
    super
    # Get info about our environment
    @ip = Socket.ip_address_list.detect{|intf| intf.ipv4_private?}.getnameinfo[0] 
    # Find the log hosts
    f = File.join(Rails.root, "config/config.yml")
    cfg = YAML.load(ERB.new(File.read(f)).result)
    @log_hosts = cfg['LOG_HOSTS'].blank? ? cfg['production']['LOG_HOSTS'] : cfg['LOG_HOSTS'] 
    # Set up the logger
    @logger = ZeroLog.new "/tmp/sub_push_#{Process.pid}", @log_hosts
    @formatter = ::Logger::Formatter.new
  end

  #
  # Utility function which returns true if the current log level is +DEBUG+ or lower.
  #
  def debug?() @level <= 0; end

  #
  # Utility function which returns true if the current log level is +INFO+ or lower.
  #
  def info?()  @level <= 1; end

  #
  # Utility function which returns true if the current log level is +WARN+ or lower.
  #
  def warn?()  @level <= 2; end

  #
  # Utility function which returns true if the current log level is +ERROR+ or lower.
  #
  def error?() @level <= 3; end

  #
  # Utility function which returns true if the current log level is +FATAL+ or lower.
  #
  def fatal?() @level <= 4; end


  #
  # This is the core method to add new log messages to the Rails log. It does nothing
  # if the level of the message is lower than the current log level, or if the message
  # is blank. Otherwise it creates a JSON log message as a hash, with data for the 
  # following keys:
  #
  # +timestamp+: The time in milliseconds since the start of the Unix epoch.
  #
  # +ip+:        The IP of the logging entity.
  #
  # +pid+:       The Process ID of the logging process.
  #
  # +service+:   The name of the service.
  #
  # +level+:     The log level of the message (0=debug, 1=info, 2=warn, etc).
  #
  # +msg+:       The log message itself. 
  #
  def add(level, msg)
    return true if level < @level
    return true if msg.blank?       # Don't send
    data = { ip:        @ip,
             pid:       Process.pid,
             service:   APP_NAME,
             level:     level
           }
    data[:token] = Thread.current[:x_api_token] if Thread.current[:x_api_token].present?
    data[:username] = Thread.current[:username] if Thread.current[:username].present?
    data[:msg] = msg if msg.is_a?(String)
    data[:timestamp] = (Time.now.utc.to_f * 1000).to_i unless data[:timestamp]
    data[:metadata] = Thread.current[:metadata] if Thread.current[:metadata].present?
    data = data.merge msg if msg.is_a?(Hash)
    @logger.log data
    true
  end


  def debug(*args)
    return if args.blank?
    add 0, *args
  end

  def info(*args)
    return if args.blank?
    add 1, *args
  end

  def warn(*args)
    return if args.blank?
    add 2, *args
  end

  def error(*args)
    return if args.blank?
    add 3, *args
  end

  def fatal(*args)
    return if args.blank?
    add 4, *args
  end

end

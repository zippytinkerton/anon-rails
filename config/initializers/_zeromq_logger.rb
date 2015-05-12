if Rails.env == 'production' && ENV['NO_ZEROMQ_LOGGING'].blank?

  def remove_existing_log_subscriptions
    ActiveSupport::LogSubscriber.log_subscribers.each do |subscriber|
      case subscriber
      when ActionView::LogSubscriber
        unsubscribe(:action_view, subscriber)
      when ActionController::LogSubscriber
        unsubscribe(:action_controller, subscriber)
      end
    end
  end

  def unsubscribe(component, subscriber)
    events = subscriber.public_methods(false).reject{ |method| method.to_s == 'call' }
    events.each do |event|
      ActiveSupport::Notifications.notifier.listeners_for("#{event}.#{component}").each do |listener|
        if listener.instance_variable_get('@delegate') == subscriber
          ActiveSupport::Notifications.unsubscribe listener
        end
      end
    end
  end

  remove_existing_log_subscriptions


  INTERNAL_PARAMS = %w(controller action format _method only_path)

  ActiveSupport::Notifications.subscribe "process_action.action_controller" do |name, started, finished, unique_id, payload|
    path = payload[:path]
    if path  != '/alive'

      runtime = finished - started
      param_method = payload[:params]['_method']
      method = param_method ? param_method.upcase : payload[:method]
      status = compute_status(payload)
      params = payload[:params].except(*INTERNAL_PARAMS)

      data = {
        timestamp:    (started.utc.to_f * 1000).to_i,
        method:       method,
        status:       status,
        runtime:      (runtime * 1000).round(0),
        view_runtime: (payload[:view_runtime] || 0).round(0),
        db_runtime:   (payload[:db_runtime] || 0).round(0)
      }
      data[:params] = params if params.present?
      data[:filter] = Thread.current[:filter] if Thread.current[:filter]
      data[:token] = Thread.current[:x_api_token] if Thread.current[:x_api_token].present?
      data[:username] = Thread.current[:username] if Thread.current[:username].present?
      data[:metadata] = Thread.current[:metadata] if Thread.current[:metadata].present?

      Thread.current[:logdata] = data
      Thread.current[:filter] = nil
      Thread.current[:x_api_token] = nil
      Thread.current[:username] = nil
      Thread.current[:cache_control] = nil
      Thread.current[:metadata] = nil
    end
  end

  def compute_status payload
    status = payload[:status]
    if status.nil? && payload[:exception].present?
      exception_class_name = payload[:exception].first
      status = ActionDispatch::ExceptionWrapper.status_code_for_exception(exception_class_name)
    end
    status
  end


  ActiveSupport::Notifications.subscribe "halted_callback.action_controller" do |*args|
    data = args.extract_options!
    Thread.current[:filter] = data[:filter]
  end


  ActiveSupport::Notifications.subscribe 'request.action_dispatch' do |*args|
    x = args.extract_options!
    request = x[:request]

    data = Thread.current[:logdata] || {}
    data[:remote_ip] = request.remote_ip
    data[:path] = request.filtered_path

    if (ac = request.env["action_controller.instance"]) && 
       (response = ac.response) && 
       (body = response.body) &&
       body.present? && 
       body =~ /\A\{"_api_error"/
      data[:_api_error] = JSON.parse(body)['_api_error']
    end

    if response && response.headers['Cache-Control']
      data[:cache_control] = response.headers['Cache-Control']
    end

    ex = request.env["action_dispatch.exception"]
    if ex 
      if data[:status] == 404
        data[:path] = request.env["REQUEST_PATH"]
      else
        # We might want to send an email here - exceptions in production
        # should be taken seriously
        data[:exception_message] = ex.message
        data[:exception_backtrace] = ex.backtrace.to_json
      end
    end

    if (data[:status] || 0) >= 500
      Rails.logger.fatal data
    elsif (data[:status] || 0) >= 400
      Rails.logger.error data
    else
      Rails.logger.info data
    end
  end


  # Announce us
  Rails.logger.info "Initialising Rails process"

  # Make sure we log our exit
  at_exit { Rails.logger.info "Exiting Rails process" }

end

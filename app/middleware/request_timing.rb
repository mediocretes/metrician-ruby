# RequestTiming and ApplicationTiming work in concert to time the middleware
# separate from the request processing. RequestTiming should be the first
# or near first middleware loaded since it will be timing from the moment
# the the app server is hit and setting up the env for tracking the
# middleware execution time. RequestTiming should be the last or near
# last middleware loaded as it times the application execution (separate from
# middleware).
class RequestTiming

  def initialize(app)
    @app = app
  end

  def call(env)
    process_start_time = Time.now.to_f
    response_size = 0

    if queue_start_time = self.class.extract_request_start_time(env)
      gauge("queue_time", process_start_time - queue_start_time)
    end

    if @request_end_time
      gauge("idle", process_start_time - @request_end_time)
      @request_end_time = nil
    end

    begin
      status, headers, body = @app.call(env)
      response_size = headers["Content-Length"]
      [status, headers, body]
    ensure
      current_route = self.class.extract_route(env["action_controller.instance"])

      request_time = env["REQUEST_TOTAL_TIME"].to_f
      env["REQUEST_TOTAL_TIME"] = nil
      gauge("request", request_time, current_route)

      if response_size && !response_size.strip.empty?
        gauge("response_size", response_size.to_i, current_route)
      end

      middleware_time = (Time.now.to_f - process_start_time) - request_time
      gauge("middleware", middleware_time)

      @request_end_time = Time.now.to_f
    end
  end

  def gauge(kind, size, route=nil)
    InstrumentalReporters.agent.gauge("web.#{kind}", size)
    InstrumentalReporters.agent.gauge("web.#{kind}.#{route}", size) if route
  end

  def self.extract_request_start_time(env)
    result = env["HTTP_X_QUEUE_START"].to_f
    result > 1_000_000_000 ? result : nil
  end

  def self.extract_route(controller)
    return "unknown_endpoint" unless controller
    controller_name = InstrumentalReporters.dotify(controller.class)
    action_name     = controller.action_name.blank? ? "unknown_action" : controller.action_name
    method_name     = controller.request.request_method.to_s
    "#{controller_name}.#{action_name}.#{method_name}".downcase
  end
end
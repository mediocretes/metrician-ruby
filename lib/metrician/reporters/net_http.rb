require "net/http"

module Metrician
  class NetHttp < Reporter

    REQUEST_METRIC = "outgoing_request"

    def self.enabled?
      !!defined?(Net::HTTP) &&
        Metrician.configuration[:external_service][:enabled]
    end

    def instrument
      return if ::Net::HTTP.ancestors.include?(Metrician::NetHttpReporterMethods)
      ::Net::HTTP.prepend(Metrician::NetHttpReporterMethods)
    end

  end

  module NetHttpReporterMethods
    start_time = Time.now
    begin
      request_without_metrician_time(req, body, &block)
    ensure
      Metrician.gauge(Metrician::NetHttp::REQUEST_METRIC, (Time.now - start_time).to_f) if Metrician.configuration[:external_service][:request][:enabled]
    end
  end
end

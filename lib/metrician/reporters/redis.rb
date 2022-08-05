module Metrician
  class Redis < Reporter

    CACHE_METRIC = "cache.command".freeze

    def self.enabled?
      !!defined?(::Redis) &&
        Metrician.configuration[:cache][:enabled]
    end

    def instrument
      return if ::Redis::Client.ancestors.include?(Metrician::RedisReporterMethods)
      ::Redis::Client.prepend(Metrician::RedisReporterMethods)
    end

  end

  module RedisReporterMethods
    def call(*args, &blk)
      start_time = Time.now
      begin
        super
      ensure
        duration = (Time.now - start_time).to_f
        Metrician.gauge(Metrician::Redis::CACHE_METRIC, duration) if Metrician.configuration[:cache][:command][:enabled]
        if Metrician.configuration[:cache][:command_specific][:enabled]
          method_name = args[0].is_a?(Array) ? args[0][0] : args[0]
          Metrician.gauge("#{Metrician::Redis::CACHE_METRIC}.#{method_name}", duration)
        end
      end
    end
  end
end

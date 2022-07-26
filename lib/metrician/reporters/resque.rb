module Metrician
  class Resque < Reporter

    def self.enabled?
      !!defined?(::Resque) &&
        Metrician::Jobs.enabled?
    end

    def instrument
      require "metrician/jobs/resque_plugin"
      unless ::Resque::Job.ancestors.include?(Metrician::Jobs::ResquePlugin::Installer)
        ::Resque::Job.prepend(Metrician::Jobs::ResquePlugin::Installer)
      end
    end

  end
end

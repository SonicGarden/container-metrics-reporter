# frozen_string_literal: true

module ContainerMetricsReporter
  class Railtie < Rails::Railtie
    initializer 'container_metrics_reporter.solid_queue_hooks' do
      SolidQueue.on_worker_start { ContainerMetricsReporter::Job.start }
      SolidQueue.on_worker_stop  { ContainerMetricsReporter::Job.stop }
    end
  end
end

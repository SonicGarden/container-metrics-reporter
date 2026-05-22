# frozen_string_literal: true

require 'socket'
require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/time/calculations'
require 'sentry-ruby'
require 'container_metrics_reporter/version'
require 'container_metrics_reporter/configuration'
require 'container_metrics_reporter/job'
require 'container_metrics_reporter/railtie' if defined?(Rails::Railtie)

module ContainerMetricsReporter
  class << self
    def configure
      yield config
    end

    def config
      @config ||= Configuration.new
    end
  end
end

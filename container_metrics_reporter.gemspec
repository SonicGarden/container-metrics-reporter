# frozen_string_literal: true

require_relative 'lib/container_metrics_reporter/version'

Gem::Specification.new do |spec|
  spec.name    = 'container-metrics-reporter'
  spec.version = ContainerMetricsReporter::VERSION
  spec.authors = ['SonicGarden']
  spec.summary = 'Report container cgroup metrics (memory, CPU) to Sentry via SolidQueue worker lifecycle hooks'

  spec.required_ruby_version = '>= 3.0'

  spec.files = Dir['lib/**/*', 'LICENSE', 'README.md']

  spec.add_dependency 'activesupport'
  spec.add_dependency 'railties'
  spec.add_dependency 'sentry-ruby'
  spec.add_dependency 'solid_queue'
  spec.metadata['rubygems_mfa_required'] = 'true'
end

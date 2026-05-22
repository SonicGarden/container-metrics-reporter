# frozen_string_literal: true

require 'logger'
require 'active_support/isolated_execution_state'
require 'container_metrics_reporter'

module Rails
  def self.logger
    @logger ||= Logger.new(IO::NULL)
  end
end

RSpec.configure do |config|
  config.before do
    ContainerMetricsReporter.instance_variable_set(:@config, nil)
  end
end

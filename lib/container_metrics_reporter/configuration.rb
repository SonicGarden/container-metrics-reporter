# frozen_string_literal: true

module ContainerMetricsReporter
  class Configuration
    attr_accessor :interval, :sleep_tick, :collect_cpu, :collect_memory, :collect_swap

    def initialize
      @interval = 5.minutes
      @sleep_tick = 5
      @collect_cpu = true
      @collect_memory = true
      @collect_swap = true
    end
  end
end

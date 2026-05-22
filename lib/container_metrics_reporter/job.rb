# frozen_string_literal: true

module ContainerMetricsReporter
  class Job
    class SentryNotConfiguredError < StandardError; end
    private_constant :SentryNotConfiguredError

    class << self
      def start
        @stop_requested = false
        @thread = Thread.new do
          Rails.logger.info '[ContainerMetricsReporter] Starting'
          job = new
          loop do
            job.perform
            break if interrupted_sleep(ContainerMetricsReporter.config.interval)
          end
          Rails.logger.info '[ContainerMetricsReporter] Stopped'
        rescue SentryNotConfiguredError
          Rails.logger.error '[ContainerMetricsReporter] Aborted'
        end
      end

      def stop
        @stop_requested = true
        @thread&.join(30)
      end

      private

      def interrupted_sleep(duration)
        deadline = Time.current + duration
        sleep ContainerMetricsReporter.config.sleep_tick until @stop_requested || Time.current >= deadline
        @stop_requested
      end
    end

    def initialize
      check_sentry
      check_memory if config.collect_memory
      check_swap if config.collect_swap
      check_cpu if config.collect_cpu
    end

    def perform
      attributes = { hostname: ENV.fetch('HOSTNAME', Socket.gethostname).split('.').first }

      send_memory(attributes) if config.collect_memory
      send_swap(attributes) if config.collect_swap
      send_cpu(attributes) if config.collect_cpu
    end

    private

    def config
      @config ||= ContainerMetricsReporter.config
    end

    def check_sentry
      return if Sentry.initialized?

      Rails.logger.error '[ContainerMetricsReporter] Sentry is not initialized. Metrics will not be sent.'
      raise SentryNotConfiguredError
    end

    def check_memory
      File.read('/sys/fs/cgroup/memory.current')
    rescue Errno::ENOENT
      Rails.logger.warn '[ContainerMetricsReporter] Cannot read memory cgroup file. Memory metrics will not be collected.'
    end

    def check_swap
      File.read('/sys/fs/cgroup/memory.swap.current')
    rescue Errno::ENOENT
      Rails.logger.warn '[ContainerMetricsReporter] Cannot read swap cgroup file. Swap metrics will not be collected.'
    end

    def check_cpu
      File.read('/sys/fs/cgroup/cpu.stat')
    rescue Errno::ENOENT
      Rails.logger.warn '[ContainerMetricsReporter] Cannot read cpu cgroup file. CPU metrics will not be collected.'
    end

    def send_memory(attributes)
      pct = usage_percent('/sys/fs/cgroup/memory.current', '/sys/fs/cgroup/memory.max')
      Sentry.metrics.gauge('container_memory_usage_percent', pct, unit: 'percent', attributes: attributes) if pct
    end

    def send_swap(attributes)
      pct = usage_percent('/sys/fs/cgroup/memory.swap.current', '/sys/fs/cgroup/memory.swap.max')
      Sentry.metrics.gauge('container_swap_usage_percent', pct, unit: 'percent', attributes: attributes) if pct
    end

    def send_cpu(attributes)
      pct = cpu_usage_percent
      Sentry.metrics.gauge('container_cpu_usage_percent', pct, unit: 'percent', attributes: attributes) if pct
    end

    def cpu_usage_percent
      current_usec = read_cpu_usec
      return unless current_usec

      prev_usec, prev_time = @last_cpu_snapshot
      @last_cpu_snapshot = [current_usec, Time.current]
      return unless prev_usec

      elapsed_usec = (Time.current - prev_time) * 1_000_000
      return if elapsed_usec <= 0

      (current_usec - prev_usec).to_f / elapsed_usec * 100
    end

    def read_cpu_usec
      stat = File.read('/sys/fs/cgroup/cpu.stat')
      stat[/usage_usec (\d+)/, 1]&.to_i
    rescue Errno::ENOENT
      nil
    end

    def usage_percent(current_path, max_path)
      current = File.read(current_path).chomp
      max = File.read(max_path).chomp
      return if current == 'max' || max == 'max'

      current.to_i * 100.0 / max.to_i
    rescue Errno::ENOENT
      nil
    end
  end
end

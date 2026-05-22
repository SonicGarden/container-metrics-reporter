# frozen_string_literal: true

RSpec.describe ContainerMetricsReporter::Job do
  let(:logger) { instance_double(Logger, info: nil, warn: nil, error: nil) }
  let(:sentry_metrics) { double('Sentry::Metrics', gauge: nil) } # rubocop:disable RSpec/VerifiedDoubles

  before do
    allow(Rails).to receive(:logger).and_return(logger)
    allow(Sentry).to receive_messages(initialized?: true, metrics: sentry_metrics)

    allow(File).to receive(:read).with('/sys/fs/cgroup/memory.current').and_return('524288000')
    allow(File).to receive(:read).with('/sys/fs/cgroup/memory.max').and_return('1073741824')
    allow(File).to receive(:read).with('/sys/fs/cgroup/memory.swap.current').and_return('0')
    allow(File).to receive(:read).with('/sys/fs/cgroup/memory.swap.max').and_return('1073741824')
    allow(File).to receive(:read).with('/sys/fs/cgroup/cpu.stat').and_return("usage_usec 1000000\n")
  end

  describe '#initialize' do
    context 'when Sentry is not initialized' do
      before { allow(Sentry).to receive(:initialized?).and_return(false) }

      it 'raises an error' do
        expect { described_class.new }.to raise_error(StandardError)
      end

      it 'logs an error message' do
        begin
          described_class.new
        rescue StandardError
          # expected
        end

        expect(logger).to have_received(:error).with(/Sentry is not initialized/)
      end
    end

    context 'when memory cgroup file is missing' do
      before do
        allow(File).to receive(:read).with('/sys/fs/cgroup/memory.current').and_raise(Errno::ENOENT)
      end

      it 'logs a warning' do
        described_class.new

        expect(logger).to have_received(:warn).with(/Cannot read memory cgroup file/)
      end
    end

    context 'when swap cgroup file is missing' do
      before do
        allow(File).to receive(:read).with('/sys/fs/cgroup/memory.swap.current').and_raise(Errno::ENOENT)
      end

      it 'logs a warning' do
        described_class.new

        expect(logger).to have_received(:warn).with(/Cannot read swap cgroup file/)
      end
    end

    context 'when cpu cgroup file is missing' do
      before do
        allow(File).to receive(:read).with('/sys/fs/cgroup/cpu.stat').and_raise(Errno::ENOENT)
      end

      it 'logs a warning' do
        described_class.new

        expect(logger).to have_received(:warn).with(/Cannot read cpu cgroup file/)
      end
    end
  end

  describe '#perform' do
    let(:job) { described_class.new }

    it 'sends memory usage gauge' do
      job.perform
      expect(sentry_metrics).to have_received(:gauge)
        .with('container_memory_usage_percent', be_within(0.1).of(48.83),
              unit: 'percent', attributes: include(hostname: anything))
    end

    it 'sends swap usage gauge' do
      job.perform
      expect(sentry_metrics).to have_received(:gauge)
        .with('container_swap_usage_percent', eq(0.0),
              unit: 'percent', attributes: include(hostname: anything))
    end

    it 'does not send cpu gauge on first perform' do
      job.perform

      expect(sentry_metrics).not_to have_received(:gauge).with('container_cpu_usage_percent', any_args)
    end

    context 'with a cpu snapshot from a previous measurement' do
      let(:base_time) { Time.now }
      let(:later_time) { base_time + 1 }

      before do
        allow(File).to receive(:read).with('/sys/fs/cgroup/cpu.stat').and_return(
          "usage_usec 1000000\n",
          "usage_usec 1000000\n",
          "usage_usec 2000000\n"
        )
        allow(Time).to receive(:current).and_return(base_time, later_time, later_time)
      end

      it 'sends cpu usage gauge on second perform' do
        job.perform
        job.perform
        expect(sentry_metrics).to have_received(:gauge)
          .with('container_cpu_usage_percent', be_within(0.1).of(100.0),
                unit: 'percent', attributes: include(hostname: anything))
      end
    end

    context 'when memory.max is "max"' do
      before { allow(File).to receive(:read).with('/sys/fs/cgroup/memory.max').and_return('max') }

      it 'does not send memory gauge' do
        job.perform

        expect(sentry_metrics).not_to have_received(:gauge).with('container_memory_usage_percent', any_args)
      end
    end

    context 'when collect_memory is false' do
      before { ContainerMetricsReporter.config.collect_memory = false }

      it 'does not send memory gauge' do
        job.perform

        expect(sentry_metrics).not_to have_received(:gauge).with('container_memory_usage_percent', any_args)
      end
    end

    context 'when collect_swap is false' do
      before { ContainerMetricsReporter.config.collect_swap = false }

      it 'does not send swap gauge' do
        job.perform

        expect(sentry_metrics).not_to have_received(:gauge).with('container_swap_usage_percent', any_args)
      end
    end

    context 'when collect_cpu is false' do
      before { ContainerMetricsReporter.config.collect_cpu = false }

      it 'does not send cpu gauge' do
        job.perform

        expect(sentry_metrics).not_to have_received(:gauge).with('container_cpu_usage_percent', any_args)
      end
    end

    context 'when hostname is configured' do
      before { allow(ContainerMetricsReporter.config).to receive(:hostname).and_return('web-1') }

      it 'uses the configured hostname' do
        job.perform
        expect(sentry_metrics).to have_received(:gauge)
          .with('container_memory_usage_percent', anything,
                unit: 'percent', attributes: { hostname: 'web-1' })
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe ContainerMetricsReporter do
  describe '.configure' do
    it 'yields the config object' do
      expect { |b| described_class.configure(&b) }.to yield_with_args(instance_of(ContainerMetricsReporter::Configuration))
    end

    it 'allows modifying config via the yielded object' do
      described_class.configure { |c| c.interval = 10 }

      expect(described_class.config.interval).to eq(10)
    end
  end

  describe '.config' do
    it 'returns a Configuration instance' do
      expect(described_class.config).to be_a(ContainerMetricsReporter::Configuration)
    end

    it 'memoizes the configuration' do
      config = described_class.config

      expect(described_class.config).to be(config)
    end
  end
end

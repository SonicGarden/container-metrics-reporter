# frozen_string_literal: true

RSpec.describe ContainerMetricsReporter::Configuration do
  subject(:config) { described_class.new }

  describe '#initialize' do
    it 'sets interval to 5 minutes' do
      expect(config.interval).to eq(5.minutes)
    end

    it 'sets sleep_tick to 5' do
      expect(config.sleep_tick).to eq(5)
    end

    it 'enables memory collection by default' do
      expect(config.collect_memory).to be(true)
    end

    it 'enables swap collection by default' do
      expect(config.collect_swap).to be(true)
    end

    it 'enables cpu collection by default' do
      expect(config.collect_cpu).to be(true)
    end
  end

  describe '#hostname' do
    context 'when HOSTNAME env is set' do
      before { stub_const('ENV', ENV.to_h.merge('HOSTNAME' => 'web-1.example.com')) }

      it 'uses the hostname without domain' do
        expect(config.hostname).to eq('web-1')
      end
    end

    context 'when HOSTNAME env is not set' do
      before do
        stub_const('ENV', ENV.to_h.except('HOSTNAME'))
        allow(Socket).to receive(:gethostname).and_return('db-server.internal')
      end

      it 'uses Socket.gethostname without domain' do
        expect(config.hostname).to eq('db-server')
      end
    end
  end

  describe 'setters' do
    it 'allows updating interval' do
      config.interval = 10.minutes

      expect(config.interval).to eq(10.minutes)
    end

    it 'allows disabling memory collection' do
      config.collect_memory = false

      expect(config.collect_memory).to be(false)
    end

    it 'allows disabling swap collection' do
      config.collect_swap = false

      expect(config.collect_swap).to be(false)
    end

    it 'allows disabling cpu collection' do
      config.collect_cpu = false

      expect(config.collect_cpu).to be(false)
    end

    it 'allows overriding hostname' do
      config.hostname = 'custom-host'

      expect(config.hostname).to eq('custom-host')
    end
  end
end

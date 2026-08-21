RSpec.describe SidekiqQueueMetricsWorker, type: :worker do
  describe 'sidekiq options' do
    it 'does not retry metric-only jobs' do
      expect(described_class.sidekiq_options['retry']).to be(false)
    end
  end

  describe '#perform' do
    subject(:perform) { described_class.new.perform }

    let(:cloudwatch_client) { instance_double(Aws::CloudWatch::Client, put_metric_data: nil) }
    let(:queue_sync) { instance_double(Sidekiq::Queue, name: 'sync', size: 3, latency: 60.0) }
    let(:queue_default) { instance_double(Sidekiq::Queue, name: 'default', size: 15, latency: 2.5) }

    before do
      allow(described_class).to receive(:client).and_return(cloudwatch_client)
      allow(TradeTariffBackend).to receive(:environment).and_return(ActiveSupport::StringInquirer.new('production'))
    end

    context 'when queues have jobs' do
      before do
        allow(Sidekiq::Queue).to receive(:all).and_return([queue_sync, queue_default])
        perform
      end

      it 'emits a single batched put_metric_data call' do
        expect(cloudwatch_client).to have_received(:put_metric_data).once
      end

      it 'emits QueueDepth and QueueLatency for each queue in the TradeTariff/Sidekiq namespace' do
        expect(cloudwatch_client).to have_received(:put_metric_data).with(
          namespace: 'TradeTariff/Sidekiq',
          metric_data: [
            {
              metric_name: 'QueueDepth',
              value: 3,
              unit: 'Count',
              dimensions: [{ name: 'Queue', value: 'sync' }, { name: 'Environment', value: 'production' }],
            },
            {
              metric_name: 'QueueLatency',
              value: 60.0,
              unit: 'Seconds',
              dimensions: [{ name: 'Queue', value: 'sync' }, { name: 'Environment', value: 'production' }],
            },
            {
              metric_name: 'QueueDepth',
              value: 15,
              unit: 'Count',
              dimensions: [{ name: 'Queue', value: 'default' }, { name: 'Environment', value: 'production' }],
            },
            {
              metric_name: 'QueueLatency',
              value: 2.5,
              unit: 'Seconds',
              dimensions: [{ name: 'Queue', value: 'default' }, { name: 'Environment', value: 'production' }],
            },
          ],
        )
      end
    end

    context 'when there are no queues' do
      before do
        allow(Sidekiq::Queue).to receive(:all).and_return([])
        perform
      end

      it 'still calls put_metric_data with an empty metric_data array' do
        expect(cloudwatch_client).to have_received(:put_metric_data).with(
          namespace: 'TradeTariff/Sidekiq',
          metric_data: [],
        )
      end
    end
  end
end

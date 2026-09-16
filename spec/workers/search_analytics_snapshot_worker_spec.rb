RSpec.describe SearchAnalyticsSnapshotWorker, type: :worker do
  it 'uses the within_1_day queue' do
    expect(described_class.sidekiq_options['queue']).to eq(:within_1_day)
  end

  it 'does not retry failures' do
    expect(described_class.sidekiq_options['retry']).to be(false)
  end

  it 'uses the configured observability channel' do
    expect(described_class.sidekiq_options['slack_channel']).to eq(TradeTariffBackend.slack_observability_channel)
  end

  it 'routes enqueued job failures to observability' do
    allow(TradeTariffBackend).to receive(:slack_failures_enabled?).and_return(true)
    allow(SlackNotifierService).to receive(:call)

    Sidekiq::Testing.fake! do
      described_class.perform_async
      job = described_class.jobs.last

      SidekiqDeathHandler.call(job, SearchAnalytics::CloudwatchSnapshotQuery::QueryError.new('CloudWatch query timed out while polling'))

      expect(SlackNotifierService).to have_received(:call).with(
        hash_including(channel: TradeTariffBackend.slack_observability_channel),
      )
    end
  end

  describe '#perform' do
    before do
      allow(SearchAnalyticsQueryWorker).to receive(:enqueue_day).and_return([])
    end

    it 'queues only yesterday rather than rolling periods' do
      described_class.new.perform
      expect(SearchAnalyticsQueryWorker).to have_received(:enqueue_day).with(
        reporting_date: Time.current.utc.to_date - 1,
        region: ENV.fetch('AWS_REGION', ENV.fetch('AWS_DEFAULT_REGION', 'eu-west-2')),
      )
    end

    it 'accepts an explicit historical day for manual collection' do
      described_class.new.perform('2026-09-14')
      expect(SearchAnalyticsQueryWorker).to have_received(:enqueue_day).with(hash_including(reporting_date: Date.new(2026, 9, 14)))
    end

    it 'handles already-queued rolling-period arguments without running the old collector' do
      expect(SearchAnalytics::SnapshotRefresh).not_to receive(:new)
      described_class.new.perform(%w[24h 7d 30d])
      expect(SearchAnalyticsQueryWorker).to have_received(:enqueue_day).with(hash_including(reporting_date: Time.current.utc.to_date - 1))
    end
  end
end

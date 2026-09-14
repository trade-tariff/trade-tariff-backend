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
    it 'delegates to the snapshot refresh service' do
      refresh = instance_double(SearchAnalytics::SnapshotRefresh, call: true)

      allow(SearchAnalytics::SnapshotRefresh).to receive(:new).and_return(refresh)

      described_class.new.perform

      expect(SearchAnalytics::SnapshotRefresh).to have_received(:new)
      expect(refresh).to have_received(:call)
    end

    it 'passes optional periods to the snapshot refresh service' do
      refresh = instance_double(SearchAnalytics::SnapshotRefresh, call: true)

      allow(SearchAnalytics::SnapshotRefresh).to receive(:new).and_return(refresh)

      described_class.new.perform(%w[30d])

      expect(SearchAnalytics::SnapshotRefresh).to have_received(:new).with(periods: %w[30d])
      expect(refresh).to have_received(:call)
    end
  end
end

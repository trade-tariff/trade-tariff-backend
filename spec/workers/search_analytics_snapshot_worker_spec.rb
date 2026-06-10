RSpec.describe SearchAnalyticsSnapshotWorker, type: :worker do
  it 'uses the within_1_day queue' do
    expect(described_class.sidekiq_options['queue']).to eq(:within_1_day)
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

RSpec.describe SearchAnalytics::SnapshotRefresh do
  subject(:refresh) do
    described_class.new(
      query_class: query_class,
      now: now,
    )
  end

  let(:query_class) { class_double(SearchAnalytics::CloudwatchSnapshotQuery) }
  let(:now) { Time.zone.parse('2026-06-10 10:00:00 UTC') }
  let(:payloads) do
    {
      'all' => { 'summary' => { 'searches' => 3 } },
      'classic' => { 'summary' => { 'searches' => 2 } },
      'internal' => { 'summary' => { 'searches' => 1 } },
    }
  end

  before do
    allow(query_class).to receive(:call).and_return(payloads)
  end

  describe '#call' do
    it 'queries CloudWatch once per supported period' do
      refresh.call

      %w[24h 7d 30d].each do |period|
        expect(query_class).to have_received(:call).with(period: period, now: now).once
      end
    end

    it 'stores one snapshot per period and view combination' do
      expect { refresh.call }.to change(SearchAnalyticsSnapshot, :count).by(9)

      snapshot = SearchAnalyticsSnapshot.latest_for(service: TradeTariffBackend.service, period: '24h', view: 'all')

      expect(snapshot).to have_attributes(
        service: TradeTariffBackend.service,
        period: '24h',
        view: 'all',
        bucket_size: 'hour',
        generated_at: now,
        data_through: now,
      )
      expect(snapshot.payload).to eq(payloads.fetch('all'))
    end

    it 'can refresh only selected periods' do
      described_class.new(
        query_class: query_class,
        now: now,
        periods: %w[30d],
      ).call

      expect(query_class).to have_received(:call).with(period: '30d', now: now).once
      expect(query_class).not_to have_received(:call).with(period: '24h', now: now)
      expect(query_class).not_to have_received(:call).with(period: '7d', now: now)
      expect(SearchAnalyticsSnapshot.where(period: '30d').count).to eq(3)
    end
  end
end

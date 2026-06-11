RSpec.describe SearchAnalyticsSnapshot do
  describe 'dataset' do
    it 'uses the current service schema from the connection search path' do
      expect(described_class.dataset.sql).to include('FROM "search_analytics_snapshots"')
      expect(described_class.dataset.sql).not_to include('public')
    end
  end

  describe 'validations' do
    let(:snapshot) { build :search_analytics_snapshot }

    it 'is valid with valid attributes' do
      expect(snapshot).to be_valid
    end

    it 'requires snapshot dimensions and payload' do
      snapshot.service = nil
      snapshot.period = nil
      snapshot.view = nil
      snapshot.bucket_size = nil
      snapshot.generated_at = nil
      snapshot.data_through = nil
      snapshot.payload = nil

      expect(snapshot).not_to be_valid
      expect(snapshot.errors.keys).to include(
        :service,
        :period,
        :view,
        :bucket_size,
        :generated_at,
        :data_through,
        :payload,
      )
    end

    it 'enforces one snapshot per service, period, view, and generated time' do
      create :search_analytics_snapshot,
             service: 'uk',
             period: '24h',
             view: 'all',
             generated_at: Time.zone.parse('2026-06-10 09:55:00 UTC')

      duplicate = build :search_analytics_snapshot,
                        service: 'uk',
                        period: '24h',
                        view: 'all',
                        generated_at: Time.zone.parse('2026-06-10 09:55:00 UTC')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors.full_messages).to include('service and period and view and generated_at is already taken')
    end
  end

  describe '.latest_for' do
    before do
      create :search_analytics_snapshot,
             service: 'uk',
             period: '24h',
             view: 'all',
             generated_at: 2.hours.ago,
             data_through: 2.hours.ago
      create :search_analytics_snapshot,
             service: 'uk',
             period: '7d',
             view: 'all',
             generated_at: 30.minutes.ago,
             data_through: 30.minutes.ago
      create :search_analytics_snapshot,
             service: 'xi',
             period: '24h',
             view: 'all',
             generated_at: 20.minutes.ago,
             data_through: 20.minutes.ago
    end

    let!(:latest_snapshot) do
      create :search_analytics_snapshot,
             service: 'uk',
             period: '24h',
             view: 'all',
             generated_at: 10.minutes.ago,
             data_through: 5.minutes.ago,
             payload: { 'summary' => { 'searches' => 2_000 } }
    end

    it 'returns the latest matching snapshot' do
      expect(described_class.latest_for(service: 'uk', period: '24h', view: 'all'))
        .to eq(latest_snapshot)
    end

    it 'returns nil when no snapshot matches' do
      expect(described_class.latest_for(service: 'uk', period: '30d', view: 'all'))
        .to be_nil
    end
  end

  describe '#payload' do
    it 'stores aggregate data as JSON' do
      payload = {
        'summary' => {
          'searches' => 1_240,
          'failure_rate' => 0.012,
        },
        'trends' => {
          'volume' => [
            { 'bucket' => '2026-06-10T09:00:00Z', 'all' => 52 },
          ],
        },
      }

      snapshot = create :search_analytics_snapshot, payload: payload

      expect(snapshot.reload.payload).to eq(payload)
    end
  end
end

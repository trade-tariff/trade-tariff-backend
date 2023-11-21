RSpec.describe QuotaEvent do
  let!(:quota_definition) { create :quota_definition }

  before do
    # Balance_event
    create :quota_balance_event, quota_definition:, occurrence_timestamp: 3.days.ago

    # Exhaustion_event
    create :quota_exhaustion_event, quota_definition:, occurrence_timestamp: 25.hours.ago

    # critical_event
    create :quota_critical_event
  end

  describe '.for_quota_definition' do
    it 'returns all quota events for specified quota_definition_sid', :aggregate_failures do
      events = described_class.for_quota_definition(quota_definition.quota_definition_sid, Time.zone.today).all
      expect(
        events.select { |ev| ev[:event_type] == 'balance' },
      ).not_to be_blank
      expect(
        events.select { |ev| ev[:event_type] == 'exhaustion' },
      ).not_to be_blank
      expect(
        events.select { |ev| ev[:event_type] == 'critical' },
      ).to be_blank
    end
  end

  describe '.last_for' do
    it 'returns last quota event type (as class) for provided quota_definition_sid value' do
      expect(
        described_class.last_for(quota_definition.quota_definition_sid, Time.zone.today),
      ).to eq QuotaExhaustionEvent
    end
  end
end

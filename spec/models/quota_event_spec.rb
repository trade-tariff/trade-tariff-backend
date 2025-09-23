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

    context 'when no events exist' do
      it 'returns NullObject' do
        expect(
          described_class.last_for(99_999, Time.zone.today),
        ).to be_a(NullObject)
      end
    end
  end

  describe '.for_event' do
    it 'returns a dataset for the specified event type' do
      dataset = described_class.for_event('balance', quota_definition.quota_definition_sid, Time.zone.today)
      expect(dataset).to be_a(Sequel::Dataset)
      expect(dataset.sql).to include('quota_balance_events')
      expect(dataset.sql).to include("'balance' AS")
    end

    it 'filters by quota_definition_sid' do
      dataset = described_class.for_event('balance', quota_definition.quota_definition_sid, Time.zone.today)
      expect(dataset.sql).to include("quota_definition_sid\" = #{quota_definition.quota_definition_sid}")
    end

    it 'filters by occurrence_timestamp' do
      point_in_time = Time.zone.today
      dataset = described_class.for_event('balance', quota_definition.quota_definition_sid, point_in_time)
      expect(dataset.sql).to include('occurrence_timestamp <= ')
    end
  end

  describe '.event_class_for' do
    it 'returns the correct event class for valid event types' do
      expect(described_class.event_class_for('balance')).to eq QuotaBalanceEvent
      expect(described_class.event_class_for('exhaustion')).to eq QuotaExhaustionEvent
      expect(described_class.event_class_for('critical')).to eq QuotaCriticalEvent
      expect(described_class.event_class_for('reopening')).to eq QuotaReopeningEvent
      expect(described_class.event_class_for('unblocking')).to eq QuotaUnblockingEvent
      expect(described_class.event_class_for('unsuspension')).to eq QuotaUnsuspensionEvent
    end

    it 'raises ArgumentError for invalid event types' do
      expect {
        described_class.event_class_for('invalid_event')
      }.to raise_error(ArgumentError, /Unknown event type: invalid_event/)
    end
  end
end

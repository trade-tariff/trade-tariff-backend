RSpec.describe QuotaStatusSql do
  describe '#to_fragment' do
    subject(:fragment) { described_class.new(definition_table:, point_in_time:).to_fragment }

    let(:definition_table) { :quota_definitions }
    let(:point_in_time) { Time.zone.parse('2026-01-01 12:00:00') }

    it 'returns a CASE expression covering exhausted, suspended, blocked, critical and open outcomes' do
      expect(fragment.str).to include('CASE')
      expect(fragment.str).to include("THEN '#{QuotaDefinition::STATUS_EXHAUSTED}'")
      expect(fragment.str).to include("THEN '#{QuotaDefinition::STATUS_SUSPENDED}'")
      expect(fragment.str).to include("THEN '#{QuotaDefinition::STATUS_BLOCKED}'")
      expect(fragment.str).to include("THEN '#{QuotaDefinition::STATUS_CRITICAL}'")
      expect(fragment.str).to include("ELSE '#{QuotaDefinition::STATUS_OPEN}'")
    end

    it 'includes all quota event tables in latest-event resolution' do
      expect(fragment.str).to include('quota_exhaustion_events')
      expect(fragment.str).to include('quota_balance_events')
      expect(fragment.str).to include('quota_critical_events')
      expect(fragment.str).to include('quota_reopening_events')
      expect(fragment.str).to include('quota_unblocking_events')
      expect(fragment.str).to include('quota_unsuspension_events')
    end

    it 'includes expected open-event types in the critical override branch' do
      expect(fragment.str).to include("'balance', 'reopening', 'unblocking', 'unsuspension'")
    end

    it 'binds point_in_time for suspension, blocking and critical-state lookups' do
      expect(fragment.args.length).to eq(5)
      expect(fragment.args).to all(eq(point_in_time))
    end

    context 'when using a custom quota definition alias' do
      let(:definition_table) { :qd }

      it 'qualifies correlated subqueries and critical_state reference with that alias' do
        expect(fragment.str).to include('"qd"."quota_definition_sid"')
        expect(fragment.str).to include('"qd"."critical_state"')
      end
    end
  end
end

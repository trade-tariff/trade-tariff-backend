describe QuotaDefinition do
  describe '#status' do
    it 'returns Open if quota definition is not in critical state' do
      quota_definition = build :quota_definition, critical_state: 'N'
      expect(quota_definition.status).to eq 'Open'
    end

    it 'returns Critical if quota definition is in critical state' do
      quota_definition = build :quota_definition, critical_state: 'Y'
      expect(quota_definition.status).to eq 'Critical'
    end
  end

  describe '#quota_balance_event_ids' do
    context 'when there are quota balance events' do
      subject(:quota_definition) { create(:quota_definition, :with_quota_balance_events) }

      it 'returns the event ids' do
        expect(quota_definition.quota_balance_event_ids.count).to be_positive
      end
    end

    context 'when there are no quota balance events' do
      subject(:quota_definition) { create(:quota_definition) }

      it 'returns empty event ids' do
        expect(quota_definition.quota_balance_event_ids).to eq([])
      end
    end
  end
end

RSpec.describe Api::Admin::QuotaOrderNumbers::QuotaCriticalEventSerializer do
  describe '#serializable_hash' do
    subject(:serialized) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:quota_critical_event) }

    let(:expected) do
      {
        data: {
          id: serializable.quota_definition_sid.to_s,
          type: :quota_critical_event,
          attributes: {
            critical_state_change_date: serializable.critical_state_change_date,
            event_type: serializable.event_type,
            critical_state: serializable.critical_state,
          },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end

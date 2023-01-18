RSpec.describe Api::Admin::QuotaOrderNumbers::QuotaExhaustionEventSerializer do
  describe '#serializable_hash' do
    subject(:serialized) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:quota_exhaustion_event) }

    let(:expected) do
      {
        data: {
          id: serializable.quota_definition_sid.to_s,
          type: :quota_exhaustion_event,
          attributes: {
            exhaustion_date: serializable.exhaustion_date,
            event_type: serializable.event_type,
          },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end

RSpec.describe Api::Admin::QuotaOrderNumbers::QuotaUnblockingEventSerializer do
  describe '#serializable_hash' do
    subject(:serialized) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:quota_unblocking_event) }

    let(:expected) do
      {
        data: {
          id: serializable.quota_definition_sid.to_s,
          type: :quota_unblocking_event,
          attributes: {
            unblocking_date: serializable.unblocking_date,
            event_type: serializable.event_type,
          },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end

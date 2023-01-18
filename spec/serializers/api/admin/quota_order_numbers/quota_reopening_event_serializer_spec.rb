RSpec.describe Api::Admin::QuotaOrderNumbers::QuotaReopeningEventSerializer do
  describe '#serializable_hash' do
    subject(:serialized) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:quota_reopening_event) }

    let(:expected) do
      {
        data: {
          id: serializable.quota_definition_sid.to_s,
          type: :quota_reopening_event,
          attributes: {
            reopening_date: serializable.reopening_date,
            event_type: serializable.event_type,
          },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end

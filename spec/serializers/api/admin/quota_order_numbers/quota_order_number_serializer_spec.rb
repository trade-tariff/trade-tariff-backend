RSpec.describe Api::Admin::QuotaOrderNumbers::QuotaOrderNumberSerializer do
  describe '#serializable_hash' do
    subject(:serialized) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:quota_order_number) }

    let(:expected) do
      {
        data: {
          id: serializable.quota_order_number_id,
          type: :quota_order_number,
          attributes: {
            quota_order_number_sid: serializable.quota_order_number_sid,
            validity_start_date: serializable.validity_start_date.iso8601,
            validity_end_date: nil,
          },
          relationships: { quota_definition: { data: nil } },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end

RSpec.describe Api::V2::QuotaOrderNumbers::QuotaOrderNumberOriginExclusionSerializer do
  describe '#serializable_hash' do
    subject(:serialized) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:quota_order_number_origin_exclusion) }

    let(:expected) do
      {
        data: {
          id: "#{serializable.quota_order_number_origin_sid}-#{serializable.excluded_geographical_area_sid}",
          type: :quota_order_number_origin_exclusion,
          relationships: {
            geographical_area: { data: { id: serializable.geographical_area.id, type: :geographical_area } },
          },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end

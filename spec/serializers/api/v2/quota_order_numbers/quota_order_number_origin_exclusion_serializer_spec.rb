RSpec.describe Api::V2::QuotaOrderNumbers::QuotaOrderNumberOriginExclusionSerializer do
  describe '#serializable_hash' do
    subject(:serialized) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:quota_order_number_origin_exclusion) }

    let(:expected) do
      {
        data: {
          id: "#{serializable.quota_order_number_origin_sid}-#{serializable.excluded_geographical_area_sid}",
          type: :quota_order_number_origin_exclusion,
          attributes: {
            excluded_geographical_area_sid: serializable.excluded_geographical_area_sid,
            quota_order_number_origin_sid: serializable.quota_order_number_origin_sid,
          },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end

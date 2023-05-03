RSpec.describe Api::V2::QuotaOrderNumbers::QuotaOrderNumberOriginSerializer do
  describe '#serializable_hash' do
    subject(:serialized) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:quota_order_number_origin, :with_geographical_area) }

    let(:expected) do
      {
        data: {
          id: serializable.id,
          type: :quota_order_number_origin,
          attributes: {
            validity_start_date: serializable.validity_start_date,
            validity_end_date: serializable.validity_end_date,
          },
          relationships: {
            geographical_area: { data: { id: serializable.geographical_area.id.to_s, type: :geographical_area } },
            quota_order_number_origin_exclusions: { data: [] },
          },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end

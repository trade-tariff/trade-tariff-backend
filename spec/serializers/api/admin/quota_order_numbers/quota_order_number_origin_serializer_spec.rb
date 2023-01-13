RSpec.describe Api::Admin::QuotaOrderNumbers::QuotaOrderNumberOriginSerializer do
    describe '#serializable_hash' do
      subject(:serialized) { described_class.new(serializable).serializable_hash }
  
      let(:serializable) { build(:quota_order_number_origin, :with_geographical_area) }
  
      let(:expected) do
        {
          data: {
            id: serializable.quota_order_number_origin_sid.to_s,
            type: :quota_order_number_origin,
            attributes: {
              geographical_area_id: serializable.geographical_area_id,
              geographical_area_description: serializable.geographical_area_description,
              validity_start_date: serializable.validity_start_date,
              validity_end_date: serializable.validity_end_date,
            },
          },
        }
      end
  
      it { is_expected.to eq(expected) }
    end
  end
  
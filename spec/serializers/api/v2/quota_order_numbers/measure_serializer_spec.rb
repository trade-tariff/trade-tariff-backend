RSpec.describe Api::V2::QuotaOrderNumbers::MeasureSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable, {}).serializable_hash }

    let(:serializable) { create(:measure, goods_nomenclature_item_id: '0101300000') }

    let(:expected_pattern) do
      {
        data: {
          id: serializable.measure_sid.to_s,
          type: :measure,
          attributes: { goods_nomenclature_item_id: '0101300000' },
        },
      }
    end

    it { is_expected.to eq(expected_pattern) }
  end
end

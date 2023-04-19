RSpec.describe Api::V2::FullChemicalSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { create(:full_chemical) }

    let(:expected) do
      {
        data: {
          id: match(/\d+-\d+/),
          type: eq(:full_chemical),
          attributes: {
            cus: serializable.cus,
            goods_nomenclature_sid: serializable.goods_nomenclature_sid,
            goods_nomenclature_item_id: serializable.goods_nomenclature_item_id,
            producline_suffix: serializable.producline_suffix,
            name: serializable.name,
            cas_rn: serializable.cas_rn,
          },
        },
      }
    end

    it { is_expected.to include_json(expected) }
  end
end

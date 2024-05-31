RSpec.describe Api::Admin::GreenLanes::GoodsNomenclatureSerializer do
  subject(:serialized) { described_class.new(serializable).serializable_hash }

  let(:serializable) { create(:commodity) }

  let(:expected) do
    {
      data: {
        id: serializable.goods_nomenclature_sid.to_s,
        type: :green_lanes_goods_nomenclature,
        attributes: {
          description: serializable.description,
          goods_nomenclature_sid: serializable.goods_nomenclature_sid,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { expect(serialized).to eq(expected) }
  end
end

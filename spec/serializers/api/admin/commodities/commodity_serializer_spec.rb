RSpec.describe Api::Admin::Commodities::CommoditySerializer do
  subject(:serialized) { described_class.new(serializable).serializable_hash }

  let(:serializable) { create(:commodity) }

  let(:expected) do
    {
      data: {
        id: serializable.admin_id,
        type: :commodity,
        attributes: {
          description: serializable.description,
          goods_nomenclature_item_id: serializable.goods_nomenclature_item_id,
          producline_suffix: serializable.producline_suffix,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { expect(serialized).to eq(expected) }
  end
end

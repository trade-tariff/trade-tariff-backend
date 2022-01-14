RSpec.describe Api::Admin::Headings::CommoditySerializer do
  subject(:serialized) { described_class.new(serializable).serializable_hash }

  let(:serializable) { create(:commodity) }

  let(:expected) do
    {
      data: {
        id: "#{serializable.goods_nomenclature_item_id}-#{serializable.producline_suffix}",
        type: :commodity,
        attributes: {
          description: serializable.description,
          search_references_count: 0,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { expect(serialized).to eq(expected) }
  end
end

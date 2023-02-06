RSpec.describe Api::Admin::Headings::CommoditySerializer do
  subject(:serialized) { described_class.new(serializable).serializable_hash }

  let(:commodity) { create(:commodity, :with_heading) }
  let(:serializable) { Api::Admin::Headings::CommodityPresenter.new(commodity, 3) }

  let(:expected) do
    {
      data: {
        id: "#{serializable.goods_nomenclature_item_id}-#{serializable.producline_suffix}",
        type: :commodity,
        attributes: {
          description: serializable.description,
          search_references_count: 3,
          declarable: true,
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

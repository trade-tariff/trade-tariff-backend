RSpec.describe Search::GoodsNomenclatureSerializer do
  describe '#to_json' do
    subject(:serialized) { described_class.new(serializable).to_json }

    let(:serializable) { create(:commodity, :with_ancestors, :with_description) }

    let(:pattern) do
      {
        goods_nomenclature_item_id: serializable.goods_nomenclature_item_id,
        description: 'Horses, other than lemmings',
      }.ignore_extra_keys!
    end

    it { is_expected.to match_json_expression pattern }
  end
end

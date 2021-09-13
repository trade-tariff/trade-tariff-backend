describe Search::CommoditySerializer do
  subject(:serializer) { described_class.new(commodity) }

  describe '#to_json' do
    context 'when commodity is declarable' do
      let(:commodity) { build :commodity, :declarable, :with_children, :with_heading }

      let(:pattern) do
        {
          goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
          producline_suffix: '80',
          declarable: true,
        }.ignore_extra_keys!
      end

      it { expect(serializer.to_json).to match_json_expression pattern }
    end

    context 'when commodity is NOT declarable' do
      let(:commodity) { build :commodity, :non_declarable, :with_children, :with_heading }

      let(:pattern) do
        {
          goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
          producline_suffix: '10',
          declarable: false,
        }.ignore_extra_keys!
      end

      it { expect(serializer.to_json).to match_json_expression pattern }
    end
  end
end

describe Search::HeadingSerializer do
  describe '#to_json' do
    let(:serializer) { described_class.new(heading) }

    context 'when heading is declarable' do
      let(:heading) { create :heading, :declarable }

      let(:pattern) do
        {
          goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
          producline_suffix: '80',
          declarable: true,
        }.ignore_extra_keys!
      end

      it 'returns json representation for ElasticSearch' do
        expect(serializer.to_json).to match_json_expression pattern
      end
    end

    context 'when heading is NOT declarable' do
      let(:heading) { create :heading, :non_declarable }

      let(:pattern) do
        {
          goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
          producline_suffix: heading.producline_suffix,
          declarable: false,
        }.ignore_extra_keys!
      end

      it 'returns json representation for ElasticSearch' do
        expect(serializer.to_json).to match_json_expression pattern
      end
    end
  end
end

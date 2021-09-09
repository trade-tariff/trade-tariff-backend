describe Search::ChapterSerializer do
  describe '#to_json' do
    let(:serializer) { described_class.new(chapter) }
    let(:chapter) { create(:chapter, :with_section, :with_description) }

    let(:pattern) do
      {
        goods_nomenclature_item_id: chapter.goods_nomenclature_item_id,
        section: Hash,
      }.ignore_extra_keys!
    end

    it 'returns json representation for ElasticSearch' do
      expect(serializer.to_json).to match_json_expression pattern
    end
  end
end

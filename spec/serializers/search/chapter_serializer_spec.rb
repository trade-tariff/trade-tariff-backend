require 'rails_helper'

describe Search::ChapterSerializer do
  describe '#to_json' do
    let!(:chapter) do
      described_class.new(
        create(:chapter, :with_section, :with_description),
      )
    end
    let(:pattern) do
      {
        goods_nomenclature_item_id: chapter.goods_nomenclature_item_id,
        section: Hash,
      }.ignore_extra_keys!
    end

    it 'returns json representation for ElasticSearch' do
      expect(chapter.to_json).to match_json_expression pattern
    end
  end
end

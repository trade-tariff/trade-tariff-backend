RSpec.describe Api::V2::Chapters::ChapterSerializer do
  subject(:serializable) { described_class.new(chapter).serializable_hash.as_json }

  let(:section) { create(:section, :with_chapter) }
  let(:chapter) { section.chapters.first }

  let(:expected) do
    {
      data: {
        id: chapter.goods_nomenclature_sid.to_s,
        type: :chapter,
        attributes: {
          goods_nomenclature_item_id: chapter.goods_nomenclature_item_id,
          description: chapter.description,
          formatted_description: chapter.formatted_description,
          validity_start_date: chapter.validity_start_date,
          validity_end_date: chapter.validity_end_date,
        },
      },
    }.as_json
  end

  describe '#serializable_hash' do
    it 'matches the expected hash' do
      expect(serializable).to include_json(expected)
    end
  end
end

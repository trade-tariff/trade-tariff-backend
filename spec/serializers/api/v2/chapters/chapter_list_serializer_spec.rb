RSpec.describe Api::V2::Chapters::ChapterListSerializer do
  subject(:serializable) { described_class.new(chapter).serializable_hash }

  let(:chapter) { create(:chapter) }

  let(:expected) do
    {
      data: {
        id: chapter.goods_nomenclature_sid.to_s,
        type: :chapter,
        attributes: {
          goods_nomenclature_sid: chapter.goods_nomenclature_sid,
          goods_nomenclature_item_id: chapter.goods_nomenclature_item_id,
          formatted_description: chapter.formatted_description,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it 'matches the expected hash' do
      expect(serializable).to eql expected
    end
  end
end

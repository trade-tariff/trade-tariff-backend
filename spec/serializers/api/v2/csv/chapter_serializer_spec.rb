RSpec.describe Api::V2::Csv::ChapterSerializer do
  describe '#serializable_array' do
    subject(:serializable_array) { described_class.new(serializable).serializable_array }

    let(:serializable) do
      chapter = create(:chapter, :with_description, :with_headings)

      [chapter]
    end

    it 'serializes correctly' do
      chapter = serializable.first

      expect(serializable_array).to eq(
        [
          %i[goods_nomenclature_sid goods_nomenclature_item_id headings_from headings_to formatted_description description],
          [
            chapter.goods_nomenclature_sid,
            chapter.goods_nomenclature_item_id,
            chapter.headings_from,
            chapter.headings_to,
            chapter.formatted_description,
            chapter.description,
          ],
        ],
      )
    end
  end
end

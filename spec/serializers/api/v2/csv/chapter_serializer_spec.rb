RSpec.describe Api::V2::Csv::ChapterSerializer do
  describe '#serializable_array' do
    subject(:serializable_array) { described_class.new(serializable).serializable_array }

    let(:serializable) do
      chapter = create(:chapter, :with_description)

      [chapter]
    end

    it 'serializes correctly' do
      chapter = serializable.first

      expect(serializable_array).to eq(
        [
          %i[goods_nomenclature_sid goods_nomenclature_item_id formatted_description],
          [
            chapter.goods_nomenclature_sid,
            chapter.goods_nomenclature_item_id,
            chapter.formatted_description,
          ],
        ],
      )
    end
  end
end

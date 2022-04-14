RSpec.describe Api::V2::Csv::SectionSerializer do
  describe '#serializable_array' do
    subject(:serializable_array) { described_class.new(serializable).serializable_array }

    let(:serializable) do
      section = create(
        :section,
        :with_chapter,
        id: 18,
        position: 18,
        numeral: 'XVIII',
        title: 'Optical, photographic, cinematographic, measuring',
      )

      [section]
    end

    it 'serializes correctly' do
      section = serializable.first

      expect(serializable_array).to eq(
        [
          %i[id numeral title position chapter_from chapter_to],
          [18, 'XVIII', 'Optical, photographic, cinematographic, measuring', 18, section.first_chapter.short_code, section.last_chapter.short_code],
        ],
      )
    end
  end
end

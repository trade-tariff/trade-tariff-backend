RSpec.describe Api::V2::Csv::SectionsSerializer do
  describe '#serializable_array' do
    subject(:serializable_array) { described_class.new(serializable).serializable_array }

    let(:serializable) do
      section = build(
        :section,
        id: 18,
        position: 18,
        numeral: 'XVIII',
        title: 'Optical, photographic, cinematographic, measuring',
      )

      [section]
    end

    it 'serializes correctly' do
      expect(serializable_array).to eq(
        [
          %i[id numeral title position chapter_from chapter_to],
          [18, 'XVIII', 'Optical, photographic, cinematographic, measuring', 18, nil, nil],
        ],
      )
    end
  end
end

RSpec.describe Api::Beta::GuideSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) do
      Hashie::TariffMash.new(
        id: 1,
        title: 'Aircraft parts',
        image: 'aircraft.png',
        url: 'https://www.gov.uk/guidance/classifying-aircraft-parts-and-accessories',
        strapline: 'Get help to classify drones and aircraft parts for import and export.',
      )
    end

    let(:expected) do
      {
        data: {
          id: '1',
          type: :guide,
          attributes: {
            title: 'Aircraft parts',
            image: 'aircraft.png',
            url: 'https://www.gov.uk/guidance/classifying-aircraft-parts-and-accessories',
            strapline: 'Get help to classify drones and aircraft parts for import and export.',
          },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end

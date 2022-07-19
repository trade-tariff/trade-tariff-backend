RSpec.describe Api::Beta::ChapterSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable, include: %w[guides]).serializable_hash }

    let(:serializable) do
      Hashie::TariffMash.new(
        {
          score: 10.231,
          goods_nomenclature_class: 'Chapter',
          id: 41_064,
          goods_nomenclature_item_id: '5200000000',
          producline_suffix: '80',
          description: 'COTTON',
          description_indexed: 'COTTON',
          chapter_description: nil,
          heading_description: nil,
          search_references: '',
          validity_start_date: '1971-12-31T00:00:00Z',
          validity_end_date: nil,
          chapter_id: '52',
          heading_id: '5200',
          ancestors: [],
          ancestor_ids: [],
          guides: [
            {
              id: 1,
              title: 'Aircraft parts',
              image: 'aircraft.png',
              url: 'https://www.gov.uk/guidance/classifying-aircraft-parts-and-accessories',
              strapline: 'Get help to classify drones and aircraft parts for import and export.',
            },
          ],
          guide_ids: [1],
        },
      )
    end

    let(:expected) do
      {
        data: {
          id: '41064',
          type: :chapter,
          attributes: {
            goods_nomenclature_item_id: '5200000000',
            producline_suffix: '80',
            description: 'COTTON',
            description_indexed: 'COTTON',
            search_references: '',
            validity_start_date: '1971-12-31T00:00:00Z',
            validity_end_date: nil,
            chapter_id: '52',
            score: 10.231,
          },
          relationships: {
            ancestors: { data: [] },
            guides: {
              data: [
                { id: '1', type: :guide },
              ],
            },
          },
        },
        included: [
          {
            attributes: {
              image: 'aircraft.png',
              strapline: 'Get help to classify drones and aircraft parts for import and export.',
              title: 'Aircraft parts',
              url: 'https://www.gov.uk/guidance/classifying-aircraft-parts-and-accessories',
            },
            id: '1',
            type: :guide,
          },
        ],
      }
    end

    it { is_expected.to eq(expected) }
  end
end

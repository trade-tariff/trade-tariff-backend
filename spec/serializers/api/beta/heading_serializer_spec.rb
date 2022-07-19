RSpec.describe Api::Beta::HeadingSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable, include: %w[ancestors guides]).serializable_hash }

    let(:serializable) do
      Hashie::TariffMash.new(
        score: 10.24,
        id: 40_961,
        goods_nomenclature_item_id: '5102000000',
        heading_id: '5102',
        chapter_id: '51',
        producline_suffix: '80',
        goods_nomenclature_class: 'Heading',
        description: 'Fine or coarse animal hair, not carded or combed',
        description_indexed: 'Fine or coarse animal hair',
        chapter_description: 'WOOL, FINE OR COARSE ANIMAL HAIR; HORSEHAIR YARN AND WOVEN FABRIC',
        heading_description: nil,
        search_references: '',
        ancestors: [
          {
            id: 40_952,
            goods_nomenclature_item_id: '5100000000',
            productline_suffix: '80',
            goods_nomenclature_class: 'Chapter',
            description: 'WOOL, FINE OR COARSE ANIMAL HAIR; HORSEHAIR YARN AND WOVEN FABRIC',
            description_indexed: 'WOOL, FINE OR COARSE ANIMAL HAIR; HORSEHAIR YARN AND WOVEN FABRIC',
          },
        ],
        ancestor_ids: [40_952],
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
        validity_start_date: '1972-01-01T00:00:00Z',
        validity_end_date: nil,
      )
    end

    let(:expected) do
      {
        data: {
          id: '40961',
          type: :heading,
          attributes: {
            goods_nomenclature_item_id: '5102000000',
            producline_suffix: '80',
            description: 'Fine or coarse animal hair, not carded or combed',
            description_indexed: 'Fine or coarse animal hair',
            search_references: '',
            validity_start_date: '1972-01-01T00:00:00Z',
            validity_end_date: nil,
            chapter_id: '51',
            score: 10.24,
            chapter_description: 'WOOL, FINE OR COARSE ANIMAL HAIR; HORSEHAIR YARN AND WOVEN FABRIC',
          },
          relationships: {
            ancestors: { data: [{ id: '40952', type: :ancestor }] },
            guides: { data: [{ id: '1', type: :guide }] },
          },
        },
        included: [
          {
            id: '40952',
            type: :ancestor,
            attributes: {
              goods_nomenclature_item_id: '5100000000',
              producline_suffix: nil,
              description: 'WOOL, FINE OR COARSE ANIMAL HAIR; HORSEHAIR YARN AND WOVEN FABRIC',
              description_indexed: 'WOOL, FINE OR COARSE ANIMAL HAIR; HORSEHAIR YARN AND WOVEN FABRIC',
            },
          },
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

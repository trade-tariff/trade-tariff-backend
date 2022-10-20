RSpec.describe Api::Beta::SubheadingSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) do
      Hashie::TariffMash.new(
        id: 73_852,
        goods_nomenclature_item_id: '5102110000',
        heading_id: '5102',
        chapter_id: '51',
        producline_suffix: '10',
        goods_nomenclature_class: 'Subheading',
        description: 'Fine animal hair',
        description_indexed: 'Fine animal hair',
        search_references: '',
        ancestors: [
          {
            id: 40_952,
            goods_nomenclature_item_id: '5100000000',
            producline_suffix: '80',
            goods_nomenclature_class: 'Chapter',
            description: 'WOOL, FINE OR COARSE ANIMAL HAIR; HORSEHAIR YARN AND WOVEN FABRIC',
            description_indexed: 'WOOL, FINE OR COARSE ANIMAL HAIR; HORSEHAIR YARN AND WOVEN FABRIC',
            formatted_description: 'Wool, fine or coarse animal hair; horsehair yarn and woven fabric',
          },
          {
            id: 40_961,
            goods_nomenclature_item_id: '5102000000',
            producline_suffix: '80',
            goods_nomenclature_class: 'Heading',
            description: 'Fine or coarse animal hair, not carded or combed',
            description_indexed: 'Fine or coarse animal hair',
            formatted_description: 'Fine or coarse animal hair, not carded or combed',
          },
        ],
        validity_start_date: '2002-01-01T00:00:00Z',
        validity_end_date: nil,
        ancestor_1_description_indexed: 'WOOL, FINE OR COARSE ANIMAL HAIR; HORSEHAIR YARN AND WOVEN FABRIC',
        ancestor_2_description_indexed: 'Fine or coarse animal hair',
        ancestor_3_description_indexed: nil,
        ancestor_4_description_indexed: nil,
        ancestor_5_description_indexed: nil,
        ancestor_6_description_indexed: nil,
        ancestor_7_description_indexed: nil,
        ancestor_8_description_indexed: nil,
        ancestor_9_description_indexed: nil,
        ancestor_10_description_indexed: nil,
        ancestor_11_description_indexed: nil,
        ancestor_12_description_indexed: nil,
        ancestor_13_description_indexed: nil,
        guides: [
          {
            id: 18,
            title: 'Textiles and textile articles',
            image: 'textiles.png',
            url: 'https://www.gov.uk/guidance/classifying-textile-apparel',
            strapline: 'Get help to classify textiles and which headings and codes to use.',
          },
        ],
        guide_ids: [18],
        declarable: false,
        ancestor_ids: [40_952, 40_961],
      )
    end

    let(:expected) do
      {
        data: {
          id: '73852',
          type: :subheading,
          attributes: {
            goods_nomenclature_item_id: '5102110000',
            producline_suffix: '10',
            description: 'Fine animal hair',
            description_indexed: 'Fine animal hair',
            search_references: '',
            validity_start_date: '2002-01-01T00:00:00Z',
            validity_end_date: nil,
            chapter_id: '51',
            score: nil,
            declarable: false,
            chapter_description: nil,
            heading_description: nil,
            heading_id: '5102',
          },
          relationships: {
            ancestors: {
              data: [
                { id: '40952', type: :ancestor },
                { id: '40961', type: :ancestor },
              ],
            },
          },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end

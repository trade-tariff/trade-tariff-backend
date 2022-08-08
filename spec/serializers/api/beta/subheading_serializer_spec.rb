RSpec.describe Api::Beta::SubheadingSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable, include: %w[ancestors]).serializable_hash }

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
        chapter_description: 'WOOL, FINE OR COARSE ANIMAL HAIR; HORSEHAIR YARN AND WOVEN FABRIC',
        heading_description: 'Fine or coarse animal hair, not carded or combed',
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
          {
            id: 40_961,
            goods_nomenclature_item_id: '5102000000',
            productline_suffix: '80',
            goods_nomenclature_class: 'Heading',
            description: 'Fine or coarse animal hair, not carded or combed',
            description_indexed: 'Fine or coarse animal hair',
          },
        ],
        ancestor_ids: [
          40_952,
          40_961,
        ],
        validity_start_date: '2002-01-01T00:00:00Z',
        validity_end_date: nil,
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
            end_line: nil,
            declarable?: false,
            chapter_description: 'WOOL, FINE OR COARSE ANIMAL HAIR; HORSEHAIR YARN AND WOVEN FABRIC',
            heading_id: '5102',
            heading_description: 'Fine or coarse animal hair, not carded or combed',
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
        included: [
          {
            id: '40952',
            type: :ancestor,
            attributes: { goods_nomenclature_item_id: '5100000000', producline_suffix: nil, description: 'WOOL, FINE OR COARSE ANIMAL HAIR; HORSEHAIR YARN AND WOVEN FABRIC', description_indexed: 'WOOL, FINE OR COARSE ANIMAL HAIR; HORSEHAIR YARN AND WOVEN FABRIC' },
          },
          {
            id: '40961',
            type: :ancestor,
            attributes: { goods_nomenclature_item_id: '5102000000', producline_suffix: nil, description: 'Fine or coarse animal hair, not carded or combed', description_indexed: 'Fine or coarse animal hair' },
          },
        ],
      }
    end

    it { is_expected.to eq(expected) }
  end
end

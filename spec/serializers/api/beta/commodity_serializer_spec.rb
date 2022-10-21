RSpec.describe Api::Beta::CommoditySerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) do
      Hashie::TariffMash.new(
        {
          score: 10.231,
          id: 40_956,
          goods_nomenclature_item_id: '5101190000',
          heading_id: '5101',
          chapter_id: '51',
          producline_suffix: '80',
          goods_nomenclature_class: 'Commodity',
          description: 'Other',
          description_indexed: 'Other',
          chapter_description: 'WOOL, FINE OR COARSE ANIMAL HAIR; HORSEHAIR YARN AND WOVEN FABRIC',
          heading_description: 'Wool, not carded or combed',
          search_references: '',
          declarable: true,
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
              id: 40_953,
              goods_nomenclature_item_id: '5101000000',
              productline_suffix: '80',
              goods_nomenclature_class: 'Heading',
              description: 'Wool, not carded or combed',
              description_indexed: 'Wool',
            },
            {
              id: 40_954,
              goods_nomenclature_item_id: '5101110000',
              productline_suffix: '10',
              goods_nomenclature_class: 'Subheading',
              description: 'Greasy, including fleece-washed wool',
              description_indexed: 'Greasy, including fleece-washed wool',
            },
          ],
          ancestor_ids: [
            40_952,
            40_953,
            40_954,
          ],
          validity_start_date: '1972-01-01T00:00:00Z',
          validity_end_date: nil,
        },
      )
    end

    let(:expected) do
      {
        data: {
          id: '40956',
          type: :commodity,
          attributes: {
            goods_nomenclature_item_id: '5101190000',
            producline_suffix: '80',
            formatted_description: nil,
            description: 'Other',
            description_indexed: 'Other',
            search_references: '',
            validity_start_date: '1972-01-01T00:00:00Z',
            validity_end_date: nil,
            chapter_id: '51',
            score: 10.231,
            declarable: true,
            chapter_description: 'WOOL, FINE OR COARSE ANIMAL HAIR; HORSEHAIR YARN AND WOVEN FABRIC',
            heading_description: 'Wool, not carded or combed',
            heading_id: '5101',
          },
          relationships: {
            ancestors: { data: [{ id: '40952', type: :chapter }, { id: '40953', type: :heading }, { id: '40954', type: :subheading }] },
          },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end

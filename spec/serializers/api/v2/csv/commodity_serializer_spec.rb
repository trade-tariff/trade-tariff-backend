RSpec.describe Api::V2::Csv::CommoditySerializer do
  describe '#serializable_array' do
    subject(:serializable_array) { described_class.new(serializable).serializable_array }

    let(:serializable) do
      commodity = Hashie::TariffMash.new(
        description: 'foo',
        number_indents: 1,
        goods_nomenclature_item_id: '0702000007',
        declarable: true,
        leaf: true,
        goods_nomenclature_sid: 123,
        formatted_description: "<span title='foo'>foo</span>",
        description_plain: 'foo',
        producline_suffix: 80,
        parent_sid: 122,
      )

      [commodity]
    end

    it 'serializes correctly' do
      expect(serializable_array).to eq(
        [
          %i[description number_indents goods_nomenclature_item_id declarable leaf goods_nomenclature_sid formatted_description description_plain producline_suffix parent_sid],
          ['foo', 1, '0702000007', true, true, 123, "<span title='foo'>foo</span>", 'foo', 80, 122],
        ],
      )
    end
  end
end

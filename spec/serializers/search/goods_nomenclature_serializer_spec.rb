RSpec.describe Search::GoodsNomenclatureSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(goods_nomenclature).serializable_hash }

    let(:goods_nomenclature) { GoodsNomenclature.find(goods_nomenclature_item_id: '0101210000') }

    let(:pattern) do
      {
        id: Integer,
        goods_nomenclature_item_id: '0101210000',
        heading_id: '0101',
        chapter_id: '01',
        producline_suffix: '80',
        goods_nomenclature_class: 'Commodity',
        chapter_description: 'Live horses, asses, mules and hinnies',
        heading_description: 'Live animals',
        description: 'Horses, other than lemmings',
        description_indexed: 'Horses',
        search_references: 'secret sauce',
        ancestors: [
          {
            id: Integer,
            goods_nomenclature_item_id: '0100000000',
            productline_suffix: '80',
            goods_nomenclature_class: 'Chapter',
            description: 'Live horses, asses, mules and hinnies',
            description_indexed: 'Live horses, asses, mules and hinnies',
          },
          {
            id: Integer,
            goods_nomenclature_item_id: '0101000000',
            productline_suffix: '80',
            goods_nomenclature_class: 'Heading',
            description: 'Live animals',
            description_indexed: 'Live animals',
          },
        ],
        validity_start_date: '2020-06-29T00:00:00Z',
        validity_end_date: nil,
      }
    end

    before do
      commodity = create(
        :commodity,
        :with_ancestors,
        goods_nomenclature_item_id: '0101210000',
        producline_suffix: '80',
        validity_start_date: Date.parse('2020-06-29'),
      )

      create(:search_reference, referenced: commodity, title: 'secret sauce')
    end

    it { is_expected.to match_json_expression(pattern) }
  end
end

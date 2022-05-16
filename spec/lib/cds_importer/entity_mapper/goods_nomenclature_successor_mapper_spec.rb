RSpec.describe CdsImporter::EntityMapper::GoodsNomenclatureSuccessorMapper do
  it_behaves_like 'an entity mapper', 'GoodsNomenclatureSuccessor', 'GoodsNomenclature' do
    let(:xml_node) do
      {
        'sid' => '27652',
        'goodsNomenclatureItemId' => '0102903131',
        'produclineSuffix' => '10',
        'goodsNomenclatureSuccessor' => {
          'absorbedGoodsNomenclatureItemId' => '0101901100',
          'absorbedProductlineSuffix' => '80',
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2017-06-29T20:04:37',
          },
        },
      }
    end

    let(:expected_values) do
      {
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        goods_nomenclature_sid: 27_652,
        absorbed_goods_nomenclature_item_id: '0101901100',
        absorbed_productline_suffix: '80',
        goods_nomenclature_item_id: '0102903131',
        productline_suffix: '10',
      }
    end
  end
end

RSpec.describe CdsImporter::EntityMapper::GoodsNomenclatureOriginMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'sid' => '27652',
        'produclineSuffix' => '80',
        'goodsNomenclatureItemId' => '0102901019',
        'goodsNomenclatureOrigin' => {
          'derivedGoodsNomenclatureItemId' => '0100000000',
          'derivedProductlineSuffix' => '80',
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
        derived_goods_nomenclature_item_id: '0100000000',
        derived_productline_suffix: '80',
        goods_nomenclature_item_id: '0102901019',
        productline_suffix: '80',
      }
    end

    let(:expected_entity_class) { 'GoodsNomenclatureOrigin' }
    let(:expected_mapping_root) { 'GoodsNomenclature' }
  end
end

RSpec.describe CdsImporter::EntityMapper::GoodsNomenclatureMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'sid' => '1234',
        'goodsNomenclatureItemId' => '9950000000',
        'produclineSuffix' => '80',
        'statisticalIndicator' => '2',
        'validityStartDate' => '2017-10-01T00:00:00',
        'validityEndDate' => '2020-09-01T00:00:00',
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2017-09-27T07:26:25',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.parse('2017-10-01T00:00:00.000Z'),
        validity_end_date: Time.parse('2020-09-01T00:00:00.000Z'),
        operation: 'C',
        operation_date: Date.parse('2017-09-27'),
        goods_nomenclature_sid: 1234,
        goods_nomenclature_item_id: '9950000000',
        producline_suffix: '80',
        statistical_indicator: 2,
      }
    end

    let(:expected_entity_class) { 'GoodsNomenclature' }
    let(:expected_mapping_root) { 'GoodsNomenclature' }
  end
end

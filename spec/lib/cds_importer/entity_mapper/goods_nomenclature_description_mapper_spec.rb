RSpec.describe CdsImporter::EntityMapper::GoodsNomenclatureDescriptionMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'sid' => '1234',
        'goodsNomenclatureItemId' => '9950000000',
        'produclineSuffix' => '80',
        'statisticalIndicator' => '2',
        'validityStartDate' => '2017-10-01T00:00:00',
        'validityEndDate' => '2020-09-01T00:00:00',
        'goodsNomenclatureDescriptionPeriod' => {
          'sid' => '1155',
          'goodsNomenclatureDescription' => {
            'description' => 'Some description.',
            'language' => {
              'languageId' => 'EN',
            },
            'metainfo' => {
              'opType' => 'U',
              'transactionDate' => '2017-08-24T04:21:16',
            },
          },
        },
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2017-09-28T09:23:15',
        },
      }
    end

    let(:expected_values) do
      {
        operation: 'U',
        operation_date: Date.parse('2017-08-24'),
        goods_nomenclature_description_period_sid: 1155,
        language_id: 'EN',
        goods_nomenclature_sid: 1234,
        goods_nomenclature_item_id: '9950000000',
        productline_suffix: '80',
        description: 'Some description.',
      }
    end

    let(:expected_entity_class) { 'GoodsNomenclatureDescription' }
    let(:expected_mapping_root) { 'GoodsNomenclature' }
  end
end

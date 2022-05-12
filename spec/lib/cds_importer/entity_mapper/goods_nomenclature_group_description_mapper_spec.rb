RSpec.describe CdsImporter::EntityMapper::GoodsNomenclatureGroupDescriptionMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'goodsNomenclatureGroupId' => '125000',
        'goodsNomenclatureGroupType' => 'T',
        'goodsNomenclatureGroupDescription' => {
          'language' => {
            'languageId' => 'EN',
          },
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
        goods_nomenclature_group_type: 'T',
        goods_nomenclature_group_id: '125000',
        language_id: 'EN',
        description: nil,
      }
    end

    let(:expected_entity_class) { 'GoodsNomenclatureGroupDescription' }
    let(:expected_mapping_root) { 'GoodsNomenclatureGroup' }
  end
end

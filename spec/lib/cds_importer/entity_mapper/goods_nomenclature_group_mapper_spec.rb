RSpec.describe CdsImporter::EntityMapper::GoodsNomenclatureGroupMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'goodsNomenclatureGroupId' => '125000',
        'goodsNomenclatureGroupType' => 'T',
        'nomenclatureGroupFacilityCode' => '123',
        'validityEndDate' => '2019-12-31T23:59:59',
        'validityStartDate' => '1991-01-01T00:00:00',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.parse('1991-01-01T00:00:00.000Z'),
        validity_end_date: Time.parse('2019-12-31T23:59:59.000Z'),
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        goods_nomenclature_group_type: 'T',
        goods_nomenclature_group_id: '125000',
        nomenclature_group_facility_code: 123,
      }
    end

    let(:expected_entity_class) { 'GoodsNomenclatureGroup' }
    let(:expected_mapping_root) { 'GoodsNomenclatureGroup' }
  end
end

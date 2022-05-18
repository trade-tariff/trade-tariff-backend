RSpec.describe CdsImporter::EntityMapper::NomenclatureGroupMembershipMapper do
  it_behaves_like 'an entity mapper', 'NomenclatureGroupMembership', 'GoodsNomenclature' do
    let(:xml_node) do
      {
        'sid' => 27_640,
        'produclineSuffix' => '80',
        'goodsNomenclatureItemId' => '0102900500',
        'nomenclatureGroupMembership' => {
          'goodsNomenclatureGroup' => {
            'goodsNomenclatureGroupId' => '010000',
            'goodsNomenclatureGroupType' => 'B',
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
        validity_start_date: nil,
        validity_end_date: nil,
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        goods_nomenclature_sid: 27_640,
        productline_suffix: '80',
        goods_nomenclature_item_id: '0102900500',
        goods_nomenclature_group_id: '010000',
        goods_nomenclature_group_type: 'B',
      }
    end
  end
end

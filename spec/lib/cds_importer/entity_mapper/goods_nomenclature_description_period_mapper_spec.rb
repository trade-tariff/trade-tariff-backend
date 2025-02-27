RSpec.describe CdsImporter::EntityMapper::GoodsNomenclatureDescriptionPeriodMapper do
  let(:xml_node) do
    {
      'sid' => '27652',
      'goodsNomenclatureItemId' => '0102901019',
      'produclineSuffix' => '80',
      'goodsNomenclatureDescriptionPeriod' => {
        'sid' => '30993',
        'validityStartDate' => '1992-03-01T00:00:00',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      },
    }
  end

  it_behaves_like 'an entity mapper', 'GoodsNomenclatureDescriptionPeriod', 'GoodsNomenclature' do
    let(:expected_values) do
      {
        validity_start_date: '1992-03-01T00:00:00.000Z',
        validity_end_date: nil,
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        goods_nomenclature_sid: 27_652,
        goods_nomenclature_description_period_sid: 30_993,
        goods_nomenclature_item_id: '0102901019',
        productline_suffix: '80',
      }
    end
  end
end

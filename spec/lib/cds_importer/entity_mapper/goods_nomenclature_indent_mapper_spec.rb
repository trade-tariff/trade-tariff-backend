RSpec.describe CdsImporter::EntityMapper::GoodsNomenclatureIndentMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'sid' => '27652',
        'goodsNomenclatureItemId' => '0102901019',
        'produclineSuffix' => '80',
        'goodsNomenclatureIndents' => {
          'sid' => '28131',
          'validityStartDate' => '1992-03-01T00:00:00',
          'numberIndents' => 5,
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2017-06-29T20:04:37',
          },
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: '1992-03-01T00:00:00.000Z',
        validity_end_date: nil,
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        goods_nomenclature_sid: 27_652,
        goods_nomenclature_indent_sid: 28_131,
        number_indents: 5,
        goods_nomenclature_item_id: '0102901019',
        productline_suffix: '80',
      }
    end

    let(:expected_entity_class) { 'GoodsNomenclatureIndent' }
    let(:expected_mapping_root) { 'GoodsNomenclature' }
  end
end

RSpec.describe CdsImporter::EntityMapper::FootnoteAssociationGoodsNomenclatureMapper do
  it_behaves_like 'an entity mapper', 'FootnoteAssociationGoodsNomenclature', 'GoodsNomenclature' do
    let(:xml_node) do
      {
        'sid' => '27652',
        'produclineSuffix' => '80',
        'goodsNomenclatureItemId' => '0102903131',
        'footnoteAssociationGoodsNomenclature' => {
          'validityEndDate' => '1992-12-31T23:59:59',
          'validityStartDate' => '1991-01-01T00:00:00',
          'footnote' => {
            'footnoteId' => '001',
            'footnoteType' => {
              'footnoteTypeId' => '5',
            },
          },
          'metainfo' => {
            'opType' => 'C',
            'origin' => 'T',
            'transactionDate' => '2016-07-25T11:07:56',
          },
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: '1991-01-01T00:00:00.000Z',
        validity_end_date: '1992-12-31T23:59:59.000Z',
        national: false,
        operation: 'C',
        operation_date: Date.parse('2016-07-25'),
        goods_nomenclature_sid: 27_652,
        productline_suffix: '80',
        goods_nomenclature_item_id: '0102903131',
        footnote_id: '001',
        footnote_type: '5',
      }
    end
  end
end
